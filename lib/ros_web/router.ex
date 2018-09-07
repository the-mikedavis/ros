defmodule ROSWeb.Router do
  use ROSWeb, :router

  pipeline :api do
    plug(:accepts, ["xml"])
  end

  scope "/", ROSWeb do
    post("/", SlaveApiController, :recv)
  end
end
