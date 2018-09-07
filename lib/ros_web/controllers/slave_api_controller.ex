defmodule ROSWeb.SlaveApiController do
  use ROSWeb, :controller

  def recv(conn, params)do
    IO.inspect(conn)
    IO.inspect(params)

    "[]"
  end
end
