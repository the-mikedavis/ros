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
    |> rename()
    |> :cowboy.start_clear([], %{env: %{dispatch: dispatch}})
  end

  @impl :cowboy_handler
  def init(req, state) do
    modified_req =
      with true <- :cowboy_req.has_body(req),
           {:ok, body, req} <- :cowboy_req.read_body(req),
           {:ok, %XMLRPC.MethodCall{} = parsed} <- XMLRPC.decode(body) do
        Logger.debug(fn -> "Received #{Map.from_struct(parsed)}." end)

        response = XMLRPC.encode!(%XMLRPC.MethodResponse{param: react(parsed)})

        :cowboy_req.reply(200, @xml_header, response, req)
      else
        a ->
          Logger.error(a)
          req
      end

    {:ok, modified_req, state}
  end

  @impl :cowboy_handler
  def terminate(_reason, _request, _state), do: :ok

  private do
    defp react(%XMLRPC.MethodCall{method_name: function_name, params: args}) do
      function_atom =
        function_name
        |> Macro.underscore()
        |> String.to_atom()

      try do
        apply(ROS.SlaveApi, function_atom, args)
      rescue
        _e in UndefinedFunctionError ->
          [-1, "method not found", function_name]
      end
    end

    defp rename(node_name) do
      String.to_atom(Atom.to_string(node_name) <> "_xmlrpc_server")
    end
  end
end
