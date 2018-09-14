defmodule ROS.Node do
  use Supervisor
  use Private
  require Logger

  @behaviour :cowboy_handler

  @xml_header %{"Content-Type" => "text/xml"}
  @default_opts []
  @api_server {ROS.SlaveApi, []}

  @doc false
  @spec start_link({[{module(), Keyword.t()}], Keyword.t()}) :: {:ok, pid()}
  def start_link({children, user_opts}) do
    name = Keyword.fetch!(user_opts, :name)

    dispatch =
      :cowboy_router.compile([
        {:_, [{:_, __MODULE__, [ROS.SlaveApi.from_node_name(name)]}]}
      ])

    opts =
      user_opts
      |> Keyword.merge(@default_opts)
      |> Keyword.put(:dispatch, dispatch)

    Supervisor.start_link(__MODULE__, {[@api_server | children], name, opts},
      name: name
    )
  end

  @impl Supervisor
  def init({children, name, opts}) do
    name
    |> comm_server_name()
    |> start_server(opts)
    |> inform_children(name, children)
    |> Supervisor.init(strategy: :one_for_one)
  end

  @impl :cowboy_handler
  def init(req, [api_server_name] = state) do
    {:ok, handle(req, api_server_name), state}
  end

  @impl :cowboy_handler
  def terminate(_reason, _request, _state), do: :ok

  private do
    @spec comm_server_name(atom()) :: atom()
    defp comm_server_name(name) do
      String.to_atom(Atom.to_string(name) <> "_xmlrpc_server")
    end

    @spec start_server(atom(), Keyword.t()) :: {String.t(), pos_integer()}
    defp start_server(name, opts) do
      :cowboy.start_clear(name, [], %{env: %{dispatch: opts[:dispatch]}})

      {local_ip(), :ranch.get_port(name)}
    end

    @spec inform_children({String.t(), pos_integer()}, atom(), [
            {module(), Keyword.t()}
          ]) :: [{module(), Keyword.t()}]
    defp inform_children(uri, name, children) do
      for {module, opts} <- children do
        {module, [uri: uri, node_name: name, children: children] ++ opts}
      end
    end

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

    @spec local_ip() :: String.t()
    def local_ip do
      {:ok, ips} = :inet.getif()

      ips
      |> Enum.map(fn {ip, _broadaddr, _mast} -> ip end)
      |> Enum.reject(fn ip -> ip == {127, 0, 0, 1} end)
      |> Enum.map(&Tuple.to_list/1)
      |> Enum.map(&Enum.join(&1, "."))
      |> List.first()
    end
  end
end
