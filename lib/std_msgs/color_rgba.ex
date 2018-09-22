defmodule StdMsgs.ColorRGBA do
  @behaviour ROS.Message.Behaviour

  @moduledoc """
  The ColorRGBA type of std_msgs.

  The definition:

  ```
  float32 r
  float32 g
  float32 b
  float32 a
  ```
  """

  @type t :: %__MODULE__{
    r: float(),
    g: float(),
    b: float(),
    a: float()
  }

  defstruct [r: 0.0, g: 0.0, b: 0.0, a: 0.0]

  @impl ROS.Message.Behaviour
  def md5sum, do: "a29a96539573343b1310c73607334b00"

  @impl ROS.Message.Behaviour
  def definition do
    """
    float32 r
    float32 g
    float32 b
    float32 a
    """
  end

  @impl ROS.Message.Behaviour
  def types do
    [
      :float32,
      :float32,
      :float32,
      :float32
    ]
  end
end
