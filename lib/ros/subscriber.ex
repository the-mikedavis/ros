defmodule ROS.Subscriber do
  use GenServer
  use Private
  require Logger
  import ROS.Helpers, only: [partial: 3]

  alias ROS.MasterApi, as: Api
  alias ROS.Message.ConnectionHeader, as: ConnHead
  alias ROS.TCP

  @moduledoc false

  ## Client API

  # open a connection to a publisher
  #
  # called by the slave_api when master gives us a message that there's someone
  # new publishing the topic
  @spec request(%ROS.Subscriber{}, atom(), String.t(), String.t(), [
          [String.t()]
        ]) :: :ok
  def request(sub, node_name, topic, publisher, transport) do
    sub
    |> NodeName.of()
    |> GenServer.cast({:request, [node_name, topic, transport, publisher]})
  end

  # don't use this struct! internal use only!

  @enforce_keys [:topic, :type, :callback]
  defstruct @enforce_keys ++ [:node_name, :uri]

  ## Server API

  def start_link(sub) do
    GenServer.start_link(__MODULE__, sub, name: NodeName.of(sub))
  end

  @impl GenServer
  def init(opts) do
    # tell master there's a new subscriber in town
    Api.register_subscriber(opts)

    look_for_publishers(opts)

    {:ok, %{sub: opts}}
  end

  @impl GenServer
  # ignore a request if you're already listening to someone else
  def handle_info({:request, pub}, %{socket: _socket} = state) do
    Logger.debug(fn ->
      "Not connecting to #{inspect(pub)} because I'm already listening to " <>
        "someone else."
    end)

    {:noreply, state}
  end

  def handle_info({:request, pub}, state) do
    apply(&request/4, pub)

    {:noreply, state}
  end

  # handle the connection header when the first full packet arrives
  def handle_info({:tcp, _socket, packet}, %{init: true} = state) do
    partial(packet, state, fn full_message ->
      full_message
      |> ROS.Message.ConnectionHeader.parse()

      # TODO do something with the connection header, like checking the md5sum

      Map.delete(state, :init)
    end)
  end

  # call the callback on each successive piece of data
  def handle_info({:tcp, _socket, packet}, %{sub: sub} = state) do
    partial(packet, state, fn full_message ->
      full_message
      |> ROS.Message.deserialize(sub.type)
      |> sub.callback.()

      state
    end)
  end

  # when the connection is closed, just close out the socket
  def handle_info({:tcp_closed, socket}, state) do
    Logger.debug(fn -> "TCP connection closed" end)

    :gen_tcp.close(socket)

    {:noreply, Map.delete(state, :socket)}
  end

  @impl GenServer
  def handle_cast({:request, pub}, state) do
    apply(&request/4, pub)

    {:noreply, state}
  end

  def handle_cast({:connect, ip, port, "TCPROS"}, %{sub: sub} = state) do
    # crack open a connection to the publisher
    {:ok, socket} =
      ip
      |> String.to_charlist()
      |> :gen_tcp.connect(port, [:binary, packet: 0])

    # forward all messages to this GenServer
    :ok = :gen_tcp.controlling_process(socket, self())

    # send the publisher my connection header
    :ok =
      sub
      |> ConnHead.from()
      |> ConnHead.serialize()
      |> TCP.send(socket)

    # now we have a socket and are expecting a connection  header
    state =
      state
      |> Map.put(:socket, socket)
      |> Map.put(:init, true)

    {:noreply, state}
  end

  private do
    # do what's needed to connect to a publisher
    @spec request(atom(), String.t(), [[String.t()]], String.t()) :: any()
    defp request(node_name, topic, transport, publisher) do
      node_name
      |> Atom.to_string()
      # request the topic *from the publisher's XML-RPC server* (not from master)
      |> Api.request_topic(topic, transport, publisher)
      |> case do
        # if they say yes, try to connect to them.
        [1, _, [protocol, ip, port]] ->
          GenServer.cast(self(), {:connect, ip, port, protocol})

        # try again in 1 second if they said no.
        _ ->
          Process.send_after(
            self(),
            {:request, [node_name, topic, transport, publisher]},
            1_000
          )
      end
    end

    # upon startup, look for publishers in case they were started before this
    # sub
    defp look_for_publishers(sub) do
      sub
      |> NodeName.of()
      |> Api.get_system_state()
      |> case do
        [1, _, [pubs, _subs, _services]] ->
          pubs
          |> Enum.filter(fn [topic, _topic_pubs] -> topic == sub.topic end)
          |> Enum.map(fn [_topic, topic_pubs] -> List.first(topic_pubs) end)
          |> subscribe_to(sub)

        _ ->
          :ok
      end
    end

    defp subscribe_to([], _sub), do: :ok

    defp subscribe_to([pub_name | _], sub) do
      sub
      |> NodeName.of()
      |> Api.lookup_node(pub_name)
      |> case do
        [1, _, pub_uri] ->
          request(sub, sub.node_name, sub.topic, pub_uri, [["TCPROS"]])

          :ok

        _ ->
          :ok
      end
    end
  end
end

defimpl NodeName, for: ROS.Subscriber do
  def of(%ROS.Subscriber{node_name: node_name, topic: topic}) do
    String.to_atom("#{node_name}_#{topic}")
  end
end
