defmodule ROS.Message.ConnectionHeader do
  use Private

  @moduledoc """
  Connection Headers proceed messages and provides a standard format
  for reading and understanding messages.
  """

  @type t :: %__MODULE__{
          callerid: String.t(),
          topic: String.t(),
          service: String.t(),
          md5sum: String.t(),
          type: struct(),
          message_definition: String.t(),
          error: String.t(),
          persistent: boolean(),
          tcp_nodelay: boolean(),
          latching: boolean()
        }

  defstruct [
    callerid: nil,
    topic: nil,
    service: nil,
    md5sum: nil,
    type: nil,
    message_definition: nil,
    error: nil,
    persistent: false,
    tcp_nodelay: false,
    latching: false
  ]

  def into(fields) do
    map =
      fields
      |> Enum.map(&translate/1)
      |> Enum.into(%{})

    struct(__MODULE__, map)
  end

  @spec parse(binary()) :: %__MODULE__{}
  def parse(packet) do
    [header_field] = ROS.Message.split(packet)

    header_field
    |> ROS.Message.split()
    |> into()
  end

  def serialize(%__MODULE__{} = _conn_header) do
    # TODO
  end

  private do
    defp translate("tcp_nodelay=0"), do: {:tcp_nodelay, false}
    defp translate("tcp_nodelay=1"), do: {:tcp_nodelay, true}
    defp translate("persistent=0"), do: {:persistent, false}
    defp translate("persistent=1"), do: {:persistent, false}
    defp translate("latching=0"), do: {:latching, false}
    defp translate("latching=1"), do: {:latching, false}
    defp translate(field) do
      [lhs, rhs] = String.split(field, "=")

      {String.to_atom(lhs), rhs}
    end
  end
end
