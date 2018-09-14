defmodule ROS.SlaveApi do
  use GenServer
  use Private

  @default_state %{remote_publishers: %{}}

  @spec start_link(Keyword.t()) :: :ok
  def start_link(opts) do
    name = Keyword.fetch!(opts, :node_name)

    GenServer.start_link(__MODULE__, opts, name: from_node_name(name))
  end

  @impl GenServer
  def init(node_info) do
    {:ok, consume(node_info)}
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
    state = put_in(state[:remote_publishers], topic, publisher_list)

    {:reply, [1, "publisher list for #{topic} updated.", 0], state}
  end

  def handle_call(
        {"requestTopic", [caller_id, topic, [["TCPROS"]]]},
        _from,
        %{node_name: node_name, local_publishers: pubs, uri: {ip, _}} = state
      ) do
    port =
      pubs
      |> Enum.find_value(fn {pub_topic, opts} -> pub_topic == topic && opts[:name] end)
      |> ROS.Publisher.connect("TCPROS")

    {:reply,
     [1, "ready on http://#{ip}:#{port}", ["TCPROS", ip, port]], state}
  end

  def handle_call({fun, _params}, _from, state) do
    {:relply, [-1, "method not found", fun], state}
  end

  private do
    @spec consume(Keyword.t()) :: %{}
    defp consume(opts) do
      {children, opts} = Keyword.pop(opts, :children, [])
      opts_map = Enum.into(opts, @default_state)

      children
      |> Enum.reduce(%{}, fn
        {ROS.Publisher, pub_opts}, acc ->
          put_in(acc[:local_publishers], %{pub_opts[:topic] => pub_opts})

        _, acc ->
          acc
      end)
      |> Map.merge(opts_map)
    end
  end
end
