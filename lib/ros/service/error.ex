defmodule ROS.Service.Error do
  @moduledoc """
  An error thrown when service calls fail. You can raise this error in your
  service callback to give the service proxy a custom message. Otherwise,
  errors raised in service callbacks will be stringified and sent as this
  error.
  """

  defexception message: "Service call failed!"
end
