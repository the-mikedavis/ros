defprotocol NodeName do
  # gives atom names to things, so they can be called as GenServers
  def of(structure)
end

defmodule ROS.Node do
  use Supervisor
  use Private
  require Logger

  @moduledoc false

  defstruct [:name, :children]

  @behaviour :cowboy_handler

  @xml_header %{"Content-Type" => "text/xml"}

  @doc false
  @spec start_link(%ROS.Node{}) :: {:ok, pid()}
  def start_link(ros_node) do
    bootstrap()

    server = %ROS.SlaveApi{node_name: ros_node.name}

    dispatch =
      :cowboy_router.compile([
        {:_, [{:_, __MODULE__, [NodeName.of(server)]}]}
      ])

    Supervisor.start_link(__MODULE__, {ros_node, server, dispatch}, name: ros_node.name)
  end

  @impl Supervisor
  def init({ros_node, server, dispatch}) do
    uri =
      server
      |> NodeName.of()
      |> start_server(dispatch)

    children = Enum.map(ros_node.children, &inform(&1, ros_node.name, uri))

    [{ROS.SlaveApi, %ROS.SlaveApi{node_name: ros_node.name, children: children, uri: uri}} | children]
    |> Supervisor.init(strategy: :one_for_one)
  end

  @impl :cowboy_handler
  def init(req, [api_server_name] = state) do
    # forward the message to the api server
    {:ok, handle(req, api_server_name), state}
  end

  @impl :cowboy_handler
  def terminate(_reason, _request, _state), do: :ok

  private do
    # startup things

    defp bootstrap do
      ROS.MasterApi.get_uri()
    end

    @spec start_server(atom(), any()) :: {String.t(), pos_integer()}
    defp start_server(name, dispatch) do
      :cowboy.start_clear(name, [], %{env: %{dispatch: dispatch}})

      {local_ip(), :ranch.get_port(name)}
    end

    @spec local_ip() :: String.t()
    defp local_ip do
      {:ok, ips} = :inet.getif()

      ips
      |> Enum.map(fn {ip, _broadaddr, _mast} -> ip end)
      |> Enum.reject(fn ip -> ip == {127, 0, 0, 1} end)
      |> List.first()
      |> Tuple.to_list()
      |> Enum.join(".")
    end

    @spec inform({module(), struct()}, atom(), {String.t(), pos_integer()})
          :: [{module(), Keyword.t()}]
    defp inform({type, child}, name, uri) do
      {type, %{child | node_name: name, uri: uri}}
    end

    # stuff for cowboy server

    @spec handle(any(), atom()) :: any()
    defp handle(req, api_server_name) do
      with true <- :cowboy_req.has_body(req),
           {:ok, body, _req} <- :cowboy_req.read_body(req),
           {:ok, %XMLRPC.MethodCall{} = parsed} <- XMLRPC.decode(body) do
        :cowboy_req.reply(200, @xml_header, reply(parsed, api_server_name), req)
      else
        a ->
          Logger.error(a)

          req
      end
    end

    @spec reply(%XMLRPC.MethodCall{}, atom()) :: binary()
    defp reply(
           %XMLRPC.MethodCall{method_name: fun, params: args} = msg,
           api_server_name
         ) do
      Logger.debug(fn -> "Received #{inspect(msg)}." end)

      return = ROS.SlaveApi.call(api_server_name, fun, args)

      XMLRPC.encode!(%XMLRPC.MethodResponse{param: return})
    end
  end
end
