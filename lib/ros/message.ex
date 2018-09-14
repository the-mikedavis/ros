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

  @doc """
  Translates from the module-ized Elixir struct name to the ROS type name.

  ## Examples

      iex> ROS.Message.module_to_type(StdMsgs.String)
      "std_msgs/String"
  """
  @spec type(String.t() | atom()) :: String.t()
  def type(type) when is_binary(type), do: type
  def type(mod) when is_atom(mod), do: module_to_type(mod)

  @doc """
  Translates from the ROS type name to the module-ized Elixir struct name.

  ## Examples

      iex> ROS.Message.type_to_module("std_msgs/String")
      StdMsgs.String
  """
  @spec module(atom() | String.t()) :: atom()
  def module(mod) when is_atom(mod), do: mod
  def module(type) when is_binary(type), do: type_to_module(type)

  def parse_as(binary, _type_module) do
    binary
    |> split()
    |> Enum.map(&split/1)
  end

  private do
    @spec module_to_type(atom()) :: String.t()
    defp module_to_type(mod) when is_atom(mod) do
      [tail | rest] =
        mod
        |> Module.split()
        |> Enum.reverse()

      [tail | Enum.map(rest, &Macro.underscore/1)]
      |> Enum.reverse()
      |> Enum.join("/")
    end

    @spec type_to_module(String.t()) :: atom()
    defp type_to_module(type) when is_binary(type) do
      type
      |> String.split("/")
      |> Enum.map(&Macro.camelize/1)
      |> List.insert_at(0, "Elixir")
      |> Enum.join(".")
      |> String.to_atom()
    end
  end
end
