defmodule ROS.SlaveApi do
  use GenServer

  @default_state %{publishers: %{}}

  def start_link(opts) do
    name = Keyword.fetch!(opts, :node_name)

    GenServer.start_link(__MODULE__, opts, name: from_node_name(name))
  end

  @impl GenServer
  def init(node_info) do
    {:ok, Enum.into(node_info, @default_state)}
  end

  @spec call(atom(), String.t(), [any()]) :: [any()]
  def call(name, method, args), do: GenServer.call(name, {method, args})

  @doc "Gets the master URI pointed to by the env var ROS MASTER URI"
  @spec master_uri() :: String.t()
  def master_uri, do: System.get_env("ROS_MASTER_URI")

  @doc "Append the node name with \"_api_server\""
  @spec from_node_name(atom()) :: atom()
  def from_node_name(name) do
    String.to_atom(Atom.to_string(name) <> "_api_server")
  end

  @impl GenServer
  def handle_call({"getMasterUri", [_caller_id]}, _from, state) do
    {:reply, [1, "ROS Master Uri", master_uri()], state}
  end

  def handle_call(
        {"publisherUpdate", ["/master", topic, publisher_list]},
        _from,
        state
      ) do
    state = put_in(state[:publishers], topic, publisher_list)

    {:reply, [1, "publisher list for #{topic} updated.", 0], state}
  end

  def handle_call(
        {"requestTopic", [_caller_id, _topic, [["TCPROS"]]]},
        _from,
        %{uri: {ip, port}} = state
      ) do
    # TODO:
    # find the `publisher` in `state`
    # ROS.Publisher.connect(publisher, caller_id, topic, "TCPROS")
    {:reply,
     [1, "ready on {ip}:{port_number}", ["TCPROS", "ip", "port_number"]], state}
  end

  def handle_call({fun, _params}, _from, state) do
    {:relply, [-1, "method not found", fun], state}
  end
end
