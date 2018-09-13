defmodule ROS.Node do
  use Supervisor
  use Private
  require Logger

  @behaviour :cowboy_handler

  @xml_header %{"Content-Type" => "text/xml"}
  @default_opts [
    dispatch: :cowboy_router.compile([{:_, [{:_, __MODULE__, []}]}])
  ]

  @doc false
  @spec start_link({[{module(), Keyword.t()}], Keyword.t()}) :: {:ok, pid()}
  def start_link({children, user_opts}) do
    opts = Keyword.merge(user_opts, @default_opts)
    name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(__MODULE__, {children, name, opts}, name: name)
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
  def init(req, state), do: {:ok, handle(req), state}

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
        {module, [uri: uri, node_name: name] ++ opts}
      end
    end

    @spec handle(any()) :: any()
    defp handle(req) do
      with true <- :cowboy_req.has_body(req),
           {:ok, body, _req} <- :cowboy_req.read_body(req),
           {:ok, %XMLRPC.MethodCall{} = parsed} <- XMLRPC.decode(body) do
        :cowboy_req.reply(200, @xml_header, reply(parsed), req)
      else
        a ->
          Logger.error(a)

          req
      end
    end

    @spec reply(%XMLRPC.MethodCall{}) :: binary()
    defp reply(%XMLRPC.MethodCall{method_name: fun, params: args} = msg) do
      Logger.debug(fn -> "Received #{inspect(msg)}." end)

      function_atom =
        fun
        |> Macro.underscore()
        |> String.to_atom()

      return =
        try do
          apply(ROS.SlaveApi, function_atom, args)
        rescue
          _e in UndefinedFunctionError ->
            [-1, "method not found", fun]
        end

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
