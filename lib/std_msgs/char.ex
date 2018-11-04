defmodule StdMsgs.Char do
  @moduledoc false
  @behaviour ROS.Message.Behaviour

  @type t :: %__MODULE__{data: non_neg_integer()}

  defstruct data: 0

  @impl ROS.Message.Behaviour
  def md5sum, do: "1bf77f25acecdedba0e224b162199717"

  @impl ROS.Message.Behaviour
  def definition do
    """
    char data
    """
  end

  @impl ROS.Message.Behaviour
  def types, do: [data: :uint8]
end
