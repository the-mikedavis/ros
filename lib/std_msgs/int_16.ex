defmodule StdMsgs.Int16 do
  @behaviour ROS.Message.Behaviour

  @moduledoc """
  The Int16 type of std_msgs.

  The definition:

  ```
  int16 data
  ```
  """

  @type t :: %__MODULE__{
    data: integer()
  }

  defstruct [data: 0]

  @impl ROS.Message.Behaviour
  def md5sum, do: "8524586e34fbd7cb1c08c5f5f1ca0e57"

  @impl ROS.Message.Behaviour
  def definition do
    """
    int16 data
    """
  end

  @impl ROS.Message.Behaviour
  def types do
    [
      :int16
    ]
  end
end
