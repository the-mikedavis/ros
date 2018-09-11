defmodule ROSWeb.SlaveApiController do
  use ROSWeb, :controller

  @moduledoc """
  An XML-RPC Server implementation using the XMLRPC plug and the
  XMLRPC library to listen and respond to XML-RPC calls.
  """

  def recv(conn, %{method_name: function, params: args}) do
    function_atom =
      function
      |> Macro.underscore()
      |> String.to_atom()

    return =
      try do
        apply(ROS.SlaveApi, function_atom, args)
      rescue
        _e in UndefinedFunctionError ->
          [-1, "method not found", function]
      end

    response = XMLRPC.encode!(%XMLRPC.MethodResponse{param: return})

    conn
    |> put_resp_header("Content-Type", "text/xml")
    |> text(response)
  end
end
