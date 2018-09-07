defmodule ROSWeb.Router do
  use ROSWeb, :router

  pipeline :api do
    plug(:accepts, ["xml"])
  end

  scope "/", ROSWeb do
    pipe_through(:api)

    get("/", SlaveApiController, :recv)
  end
end
