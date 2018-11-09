defmodule ROS do
  @moduledoc """
  A ROS client library for Elixir.
  """

  @doc """
  Aliases common modules and imports the `ROS.Node.Spec`

  - ROS.Publisher -> Publisher
  - ROS.Subscriber -> Subscriber
  - ROS.Service -> Service
  - ROS.Service.Proxy -> ServiceProxy

  The `ROS.Node.Spec` allows you to easily define the structure of your
  program when starting the application.
  """
  defmacro __using__(_) do
    quote do
      alias ROS.{Publisher, Subscriber, Service}
      alias ROS.Service.Proxy, as: ServiceProxy
      import ROS.Node.Spec
    end
  end
end
