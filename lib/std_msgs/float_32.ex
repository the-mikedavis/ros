defmodule StdMsgs.Float32 do
  @behaviour ROS.Message.Behaviour

  @moduledoc """
  The Float32 type of std_msgs.

  The definition:

  ```
  float32 data
  ```
  """

  @type t :: %__MODULE__{
    data: integer()
  }

  defstruct [data: 0.0]

  @impl ROS.Message.Behaviour
  def md5sum, do: "73fcbf46b49191e672908e50842a83d4"

  @impl ROS.Message.Behaviour
  def definition do
    """
    float32 data
    """
  end

  @impl ROS.Message.Behaviour
  def types do
    [
      :float32
    ]
  end
end
