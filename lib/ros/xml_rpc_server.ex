defmodule ROS.XMLRPCServer do
  use Private
  use GenServer
  require Logger

  @xml_header %{"Content-Type" => "text/xml"}
  @behaviour :cowboy_handler

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    dispatch = :cowboy_router.compile([{:_, [{:_, __MODULE__, []}]}])

    GenServer.start_link(__MODULE__, {name, dispatch}, name: __MODULE__)
  end

  @impl GenServer
  def init({name, dispatch}) do
    name
    |> from_node_name()
    |> :cowboy.start_clear([], %{env: %{dispatch: dispatch}})
  end

  @impl :cowboy_handler
  def init(req, state) do
    modified_req =
      with true <- :cowboy_req.has_body(req),
           {:ok, body, _req} <- :cowboy_req.read_body(req),
           {:ok, %XMLRPC.MethodCall{} = parsed} <- XMLRPC.decode(body) do
        :cowboy_req.reply(200, @xml_header, handle(parsed), req)
      else
        a ->
          Logger.error(a)

          req
      end

    {:ok, modified_req, state}
  end

  @doc "Gives a name for an XML-RPC supervisor given a Node name"
  @spec from_node_name(atom()) :: atom()
  def from_node_name(node_name) do
    String.to_atom(Atom.to_string(node_name) <> "_xmlrpc_server")
  end

  @impl :cowboy_handler
  def terminate(_reason, _request, _state), do: :ok

  private do
    @spec handle(%XMLRPC.MethodCall{}) :: binary()
    defp handle(%XMLRPC.MethodCall{method_name: fun, params: args} = msg) do
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
  end
end
