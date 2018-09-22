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
    {field, rest} = split_once(binary)

    [field | split(rest)]
  end

  @doc """
  Splits a field off once. Used in the recursive implementation of split.
  """
  @spec split_once(binary()) :: {binary(), binary()}
  def split_once(binary) do
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

    {field, rest}
  end

  @doc """
  Translates from the module-ized Elixir struct name to the ROS type name.

  ## Examples

      iex> ROS.Message.type(StdMsgs.String)
      "std_msgs/String"
  """
  @spec type(String.t() | atom()) :: String.t()
  def type(type) when is_binary(type), do: type
  def type(mod) when is_atom(mod), do: module_to_type(mod)

  @doc """
  Translates from the ROS type name to the module-ized Elixir struct name.

  ## Examples

      iex> ROS.Message.module("std_msgs/String")
      StdMsgs.String
  """
  @spec module(atom() | String.t()) :: atom()
  def module(mod) when is_atom(mod), do: mod
  def module(type) when is_binary(type), do: type_to_module(type)

  # TODO: parse into struct
  def parse_as(binary, type_module) when is_binary(type_module) do
    parse_as(binary, type_to_module(type_module))
  end
  def parse_as(binary, type_module) do
    parsed_kw_list =
      binary
      |> split()
      |> List.first()
      |> _parse(type_module.types(), [])

    struct(type_module, parsed_kw_list)
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

  # TODO: move into private block
  # a tail recursive parser
  @spec _parse(binary(), [{atom(), atom()}], [any()]) :: [any()]
  def _parse(<<>>, _types, acc), do: acc
  def _parse(_binary, [], acc), do: acc
  def _parse(binary, [{name, :string} | other_types], acc) do
    {str, rest} = split_once(binary)

    _parse(rest, other_types, [{name, str} | acc])
  end
  def _parse(binary, [{name, type} | other_types], acc) do
    {value, rest} = Satchel.unpack_take(binary, type)

    _parse(rest, other_types, [{name, value} | acc])
  end
end
