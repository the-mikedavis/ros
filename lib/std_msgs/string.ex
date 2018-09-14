defmodule StdMsgs.String do
  @moduledoc """
  The String type of std_msgs.

  The definition:

  ```
  string data
  ```
  """

  @type t :: %__MODULE__{data: String.t()}

  defstruct [data: ""]

  @spec md5sum() :: String.t()
  def md5sum, do: "992ce8a1687cec8c8bd883ec73ca41d1"

  @spec definition() :: String.t()
  def definition, do: "string data\n"
end
