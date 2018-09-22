defmodule StdMsgs.String do
  @behaviour ROS.Message.Behaviour

  @moduledoc """
  The String type of std_msgs.

  The definition:

  ```
  string data
  ```
  """

  @type t :: %__MODULE__{data: String.t()}

  defstruct data: ""

  @impl ROS.Message.Behaviour
  def md5sum, do: "992ce8a1687cec8c8bd883ec73ca41d1"

  @impl ROS.Message.Behaviour
  def definition, do: "string data\n"

  @impl ROS.Message.Behaviour
  def types do
    [
      data: :string
    ]
  end
end
