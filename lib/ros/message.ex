defmodule ROS.Message do
  use Private

  @moduledoc """
  Logic and helper functions for handling ROS messages sent between nodes.
  """

  # The number of bytes to read to see how long a field is

  @block_length 4

  @doc """
  Translates a string of data from a binary packet.

  The leading field is a set of 4 little endian bytes representing an integer.
  That integer describes the length of the following field. This function
  reads that integer (call it `n`) and then takes the next segment of `n`
  bytes from the binary. It does this recursively until the binary has ended.

  This is appropriate for using nestedly, by applying a binary and then
  applying element-wise to the list produced.
  """
  @spec split(binary()) :: []
  def split(<<>>), do: []

  def split(binary) do
    field_length =
      binary
      |> Bite.take(@block_length, 'l')
      |> Bite.to_integer()

    field =
      binary
      |> Bite.drop(@block_length)
      |> Bite.take(field_length)
      |> Bite.to_string()

    rest = Bite.drop(binary, @block_length + field_length)

    [field | split(rest)]
  end

  def parse_as(binary, _type_module) do
    binary
    |> split()
    |> List.first()
    |> split()
  end
end
