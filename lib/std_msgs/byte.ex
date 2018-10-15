defmodule StdMsgs.Byte do
  @behaviour ROS.Message.Behaviour

  @type t :: %__MODULE__{data: integer()}

  defstruct data: 0

  @impl ROS.Message.Behaviour
  def md5sum, do: "ad736a2e8818154c487bb80fe42ce43b"

  @impl ROS.Message.Behaviour
  def definition do
    """
    byte data
    """
  end

  @impl ROS.Message.Behaviour
  def types, do: [data: :int8]
end
