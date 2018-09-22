defmodule ROS.Message.Behaviour do
  @doc "Show the message's md5sum, which is useful for message versioning"
  @callback md5sum() :: String.t()

  @doc "Show the message's definition"
  @callback definition() :: String.t()

  @doc "Give the message's types as atoms in the order to be parsed"
  @callback types() :: [atom()]
end
