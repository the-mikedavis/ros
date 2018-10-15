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
    field_length = Satchel.unpack(binary, :uint32)

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

  @doc """
  Deserialize a binary message from a publisher into an Elixir struct.

  ## Examples

      iex> data = <<16, 0, 0, 0, 0, 0, 176, 65, 0, 0, 4, 66, 0, 0, 48, 66, 0, 0, 0, 0>>
      iex> ROS.Message.deserialize(data, "std_msgs/ColorRGBA")
      %StdMsgs.ColorRGBA{r: 22.0, g: 33.0, b: 44.0, a: 0.0}
      iex> ROS.Message.deserialize(data, StdMsgs.ColorRGBA)
      %StdMsgs.ColorRGBA{r: 22.0, g: 33.0, b: 44.0, a: 0.0}
  """
  @spec deserialize(binary(), module() | String.t()) :: struct()
  def deserialize(binary, type_module) when is_binary(type_module) do
    deserialize(binary, type_to_module(type_module))
  end

  def deserialize(binary, type_module) do
    # TODO: do this in the tcp module
    {innards, _left_overs} = split_once(binary)

    {parsed_kw_list, _rest} = _parse_take(innards, type_module.types(), [])

    struct(type_module, parsed_kw_list)
  end

  @spec deserialize_take(binary(), module() | binary()) :: {struct(), binary()}
  def deserialize_take(binary, type) when is_binary(type) do
    deserialize_take(binary, type_to_module(type))
  end
  def deserialize_take(binary, type_module) do
    {parsed_kw_list, rest} = _parse_take(binary, type_module.types(), [])

    {struct(type_module, parsed_kw_list), rest}
  end

  @doc """
  Serialize an Elixir struct to a binary transmittable over the wire.

  ## Examples

    iex> data = %StdMsgs.ColorRGBA{r: 22.0, g: 33.0, b: 44.0, a: 0.0}
    iex> ROS.Message.serialize(data)
    <<16, 0, 0, 0, 0, 0, 176, 65, 0, 0, 4, 66, 0, 0, 48, 66, 0, 0, 0, 0>>
  """
  @spec serialize(struct()) :: binary()
  def serialize(%type{} = msg), do: _serialize(type.types(), "", msg)

  private do
    @spec _serialize([{atom(), atom()}], binary(), struct()) :: binary()
    defp _serialize([], acc, _), do: pack_string(acc)
    defp _serialize([{name, :string} | other_types], acc, msg) do
      _serialize(other_types, acc <> pack_string(Map.get(msg, name)), msg)
    end
    defp _serialize([{name, type} | other_types], acc, msg) do
      type_string = Atom.to_string(type)

      addition =
        cond do
          # List/Array
          String.contains?(type_string, "[]") ->
            serialize_list(Map.get(msg, name), type)

          # Module
          String.contains?(type_string, "/") ->
            sub_msg = Map.get(msg, name)
            serialize(sub_msg)

          # Normal Built-in types
          true ->
            Satchel.pack(Map.get(msg, name), type)
        end

      _serialize(other_types, acc <> addition, msg)
    end

    defp serialize_list(list, type) do
      serialized_length = Satchel.pack(:uint32, length(list))

      serialized_list =
        list
        |> Enum.map(&Satchel.pack(type, &1))
        |> Enum.join("")

      serialized_length <> serialized_list
    end

    # turn 168 -> <<168, 0, 0, 0>>
    @spec length_field(non_neg_integer()) :: binary()
    defp length_field(len), do: <<len::little-integer-32>>

    @spec pack_string(binary()) :: binary()
    defp pack_string(str) do
      len_field =
        str
        |> String.length()
        |> length_field()

      len_field <> str
    end

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

    # a tail recursive parser used by `deserialize/2`
    @spec _parse_take(binary(), [{atom(), atom()}], [any()]) :: {any(), binary()}
    def _parse_take(<<>>, _types, acc), do: {acc, <<>>}
    def _parse_take(binary, [], acc), do: {acc, binary}

    def _parse_take(binary, [{name, :string} | other_types], acc) do
      {str, rest} = split_once(binary)

      _parse_take(rest, other_types, [{name, str} | acc])
    end

    def _parse_take(binary, [{name, type} | other_types], acc) do
      type_string = Atom.to_string(type)

      array? = String.ends_with?(type_string, "[]")
      module? = String.contains?(type_string, "/")

      {value, rest} =
        cond do
          array? and module? ->
            module =
              type
              |> Atom.to_string()
              |> String.trim("[]")

            deserialize_take_list(binary, module)

          array? ->
            unlisted_type =
              type
              |> Atom.to_string()
              |> String.trim("[]")
              |> String.to_atom()

            unpack_take_list(binary, unlisted_type)

          module? ->
            deserialize_take(binary, Atom.to_string(type))

          true ->
            Satchel.unpack_take(binary, type)
        end

      _parse_take(rest, other_types, [{name, value} | acc])
    end

    defp unpack_take_list(binary, type) do
      {list_length, rest} = Satchel.unpack_take(binary, :uint32)

      unpack_take_list(rest, type, list_length, [])
    end

    defp unpack_take_list(binary, _type, 0, acc), do: {acc, binary}
    defp unpack_take_list(binary, type, n, acc) do
      {value, rest} = Satchel.unpack_take(binary, type)

      unpack_take_list(rest, type, n - 1, [value | acc])
    end

    # parse a module array
    defp deserialize_take_list(binary, type) do
      {list_length, rest} = Satchel.unpack_take(binary, :uint32)

      deserialize_take_list(rest, type, list_length, [])
    end
    defp deserialize_take_list(binary, _type, 0, acc), do: {acc, binary}
    defp deserialize_take_list(binary, type, n, acc) do
      {value, rest} = deserialize_take(binary, type)

      deserialize_take_list(rest, type, n - 1, [value | acc])
    end
  end
end
