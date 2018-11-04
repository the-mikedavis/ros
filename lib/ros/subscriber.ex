defmodule ROS.Subscriber do
  use GenServer
  require Logger
  import ROS.Helpers, only: [partial: 3]

  alias ROS.MasterApi, as: Api
  alias ROS.Message.ConnectionHeader, as: ConnHead
  alias ROS.TCP

  @moduledoc false

  ## Client API

  @spec request(Keyword.t(), atom(), String.t(), String.t(), [[String.t()]]) ::
          :ok
  def request(sub, node_name, topic, publisher, transport) do
    name = Keyword.fetch!(sub, :name)

    GenServer.cast(name, {:request, [node_name, topic, transport, publisher]})
  end

  ## Server API

  def from_node_name(node_name, opts) do
    String.to_atom(Atom.to_string(node_name) <> "_" <> opts[:topic])
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    Api.register_subscriber(opts)

    {:ok, %{sub: opts}}
  end

  @impl GenServer
  def handle_info({:request, pub}, state) do
    apply(&request/4, pub)

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, packet}, %{init: true} = state) do
    partial(packet, state, fn full_message ->
      full_message
      |> ROS.Message.ConnectionHeader.parse()
      # TODO do something with the connection header, like checking the md5sum

      Map.delete(state, :init)
    end)
  end

  def handle_info({:tcp, _socket, packet}, %{sub: sub} = state) do
    partial(packet, state, fn full_message ->
      full_message
      |> ROS.Message.deserialize(sub[:type])
      |> sub[:callback].()

      state
    end)
  end

  def handle_info({:tcp_closed, socket}, state) do
    Logger.debug(fn -> "TCP connection closed" end)

    :gen_tcp.close(socket)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:request, pub}, state) do
    apply(&request/4, pub)

    {:noreply, state}
  end

  def handle_cast({:connect, ip, port, "TCPROS"}, %{sub: sub} = state) do
    {:ok, socket} =
      ip
      |> String.to_charlist()
      |> :gen_tcp.connect(port, [:binary, packet: 0])

    :ok = :gen_tcp.controlling_process(socket, self())

    :ok =
      sub
      |> ConnHead.from()
      |> ConnHead.serialize()
      |> TCP.send(socket)

    state =
      state
      |> Map.put(:socket, socket)
      |> Map.put(:init, true)

    {:noreply, state}
  end

  @spec connect(
          Keyword.t(),
          String.t(),
          pos_integer(),
          String.t()
        ) :: :ok
  def connect(subscriber, ip, port, "TCPROS") do
    spec = {ROS.TCP, %{sub: subscriber}}

    {:ok, pid} = DynamicSupervisor.start_child(subscriber[:name], spec)

    GenServer.cast(pid, {:connect, ip, port})
  end

  @spec request(atom(), String.t(), [[String.t()]], String.t()) :: any()
  defp request(node_name, topic, transport, publisher) do
    node_name
    |> Atom.to_string()
    |> Api.request_topic(topic, transport, publisher)
    |> case do
      [1, _, [protocol, ip, port]] ->
        GenServer.cast(self(), {:connect, ip, port, protocol})

      _ ->
        Process.send_after(self(), {:request, [node_name, topic, transport, publisher]}, 1_000)
    end
  end
end
