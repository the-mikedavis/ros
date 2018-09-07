defmodule ROS.Message do
  @moduledoc """
  Logic and helper functions for handling ROS messages sent between nodes.
  """

  # The number of bytes to read to see how long a field is
  @block_length 4

  def split_field(<<>>), do: []

  def split_field(binary) do
    field_length =
      binary
      |> Bite.take(@block_length, 'hl')
      |> Bite.to_integer()

    field =
      binary
      |> Bite.drop(@block_length)
      |> Bite.take(field_length)

    rest = Bite.drop(binary, @block_length + field_length)

    [field | split_field(rest)]
  end
end
