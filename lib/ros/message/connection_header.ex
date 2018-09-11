defmodule ROS.Message.ConnectionHeader do
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
    :callerid,
    :topic,
    :service,
    :md5sum,
    :type,
    :message_definition,
    :error,
    :persistent,
    :tcp_nodelay,
    :latching
  ]

  def into(fields) do
    map =
      fields
      |> Enum.map(&String.split(&1, "="))
      |> Enum.reduce(%{}, fn [lhs, rhs], acc ->
        Map.put(acc, String.to_atom(lhs), rhs)
      end)

    struct(__MODULE__, map)
  end
end
