defmodule ROS.SlaveApi do
  use GenServer
  use Private
  require Logger

  @moduledoc false
  # this module just keeps track of the publishers and subscribers of a node.
  # each node has 1 slave_api child.

  @default_state %{remote_publishers: %{}}

  defstruct [:children, :node_name, :uri]

  @spec start_link(Keyword.t()) :: :ok
  def start_link(server) do
    GenServer.start_link(__MODULE__, server, name: NodeName.of(server))
  end

  @impl GenServer
  def init(server), do: {:ok, consume(server)}

  @spec call(atom(), String.t(), [any()]) :: [any()]
  def call(name, method, args), do: GenServer.call(name, {method, args})

  @doc "Gets the master URI pointed to by the env var ROS MASTER URI"
  @spec master_uri() :: String.t()
  def master_uri, do: System.get_env("ROS_MASTER_URI")

  @impl GenServer
  def handle_call({"getMasterUri", [_caller_id]}, _from, state) do
    {:reply, [1, "ROS Master Uri", master_uri()], state}
  end

  # catch the empty list of publishers (when a publisher dies)
  def handle_call({"publisherUpdate", ["/master", topic, []]}, _from, state) do
    state = put_in(state[:remote_publishers], %{topic => []})

    {:reply, [1, "thanks for the update.", 0], state}
  end

  def handle_call(
        {"publisherUpdate", ["/master", topic, publisher_list]},
        _from,
        %{local_subs: all_subs} = state
      ) do
    state = put_in(state[:remote_publishers], %{topic => publisher_list})

    case Map.fetch(all_subs, topic) do
      :error ->
        {:reply, [1, "go fish. i don't have that sub.", 1], state}

      {:ok, sub} ->
        pub = List.first(publisher_list)
        ROS.Subscriber.request(sub, sub.node_name, topic, pub, [["TCPROS"]])

        {:reply, [1, "publisher list for #{topic} updated.", 0], state}
    end
  end

  def handle_call(
        {"requestTopic", [_caller_id, topic, [["TCPROS"]]]},
        _from,
        %{local_pubs: pubs, slave_api: %{uri: {ip, _port}}} = state
      ) do
    # get the first pub that has this topic and call its connect function
    port =
      pubs
      |> Enum.find_value(fn {pub_topic, pub} ->
        pub_topic == topic && pub
      end)
      |> ROS.Publisher.connect("TCPROS")

    {:reply, [1, "ready on http://#{ip}:#{port}", ["TCPROS", ip, port]], state}
  end

  def handle_call({fun, _params}, _from, state) do
    Logger.warn(fn -> "no implementation for #{fun} in slave api" end)
    {:reply, [-1, "method not found", fun], state}
  end

  private do
    @spec consume(Keyword.t()) :: %{}
    defp consume(%ROS.SlaveApi{children: children} = slave_api) do
      children
      |> Enum.reduce(%{}, &add_to_map/2)
      |> Map.merge(@default_state)
      |> Map.put(:slave_api, slave_api)
    end

    defp add_to_map({ROS.Publisher, pub}, acc) do
      put_in(acc[:local_pubs], %{pub.topic => pub})
    end

    defp add_to_map({ROS.Subscriber, sub}, acc) do
      put_in(acc[:local_subs], %{sub.topic => sub})
    end

    defp add_to_map(_, acc), do: acc
  end
end

defimpl NodeName, for: ROS.SlaveApi do
  def of(%ROS.SlaveApi{node_name: node_name}) do
    String.to_atom("#{node_name}_xml_rpc_server")
  end
end
