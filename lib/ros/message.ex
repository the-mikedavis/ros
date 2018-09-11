defmodule ROS.Message do
  use Private

  @moduledoc """
  Logic and helper functions for handling ROS messages sent between nodes.
  """

  # The number of bytes to read to see how long a field is

  def parse(packet) do
    [header_field | message] = split_field(packet)

    {split_field(header_field), message}
  end

  private do
    @block_length 4

    @spec split_field(binary()) :: []
    def split_field(<<>>), do: []

    def split_field(binary) do
      field_length =
        binary
        |> Bite.take(@block_length, 'l')
        |> Bite.to_integer()

      field = binary |> Bite.drop(@block_length)

      rest = Bite.drop(binary, @block_length + field_length)

      [field | split_field(rest)]
    end
  end
end
