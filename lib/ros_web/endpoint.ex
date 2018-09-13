defmodule ROSWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ros

  socket("/socket", ROSWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, :xmlrpc],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    xmlrpc_decoder: XMLRPC
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_ros_key",
    signing_salt: "8ZfDo/MA"
  )

  plug(ROSWeb.Router)

  def init(_key, config) do
    {:ok, config}
  end
end
