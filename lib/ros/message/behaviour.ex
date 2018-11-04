defmodule ROS.Message.Behaviour do
  @moduledoc false
  # The behaviour held by every message. Every message should be able to produce
  # its md5sum, its definition, and the types, for serializing

  @doc "Show the message's md5sum, which is useful for message versioning"
  @callback md5sum() :: String.t()

  @doc "Show the message's definition"
  @callback definition() :: String.t()

  @doc "Give the message's types as atoms in the order to be parsed"
  @callback types() :: [atom()]
end
