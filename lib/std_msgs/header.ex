defmodule StdMsgs.Header do
  @behaviour ROS.Message.Behaviour

  @moduledoc """
  The Header type of std_msgs.

  The definition:

  ```
  uint32 seq
  time stamp
  string frame_id
  ```
  """

  @type t :: %__MODULE__{
          seq: integer(),
          stamp: Time.t(),
          frame_id: String.t()
        }

  defstruct seq: nil, stamp: Time.utc_now(), frame_id: ""

  @impl ROS.Message.Behaviour
  def md5sum, do: "2176decaecbce78abc3b96ef049fabed"

  @impl ROS.Message.Behaviour
  def definition do
    """
    uint32 seq
    time stamp
    string frame_id
    """
  end

  @impl ROS.Message.Behaviour
  def types do
    [
      seq: :uint32,
      stamp: :time,
      frame_id: :string
    ]
  end
end
