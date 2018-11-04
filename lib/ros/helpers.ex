defmodule ROS.Helpers do
  @moduledoc false

  # Helpers for internal use

  # executes a function once a full packet has been received; if it has
  # not been fully received, wait until the next call
  #
  # the function must return `state`
  defmacro partial(packet, state, callback) do
    quote do
      # get the partial packet from the state, an empty binary otherwise
      partial = Map.get(unquote(state), :partial, "")
      # concatenate that partial packet with this new arrival
      packet = partial <> unquote(packet)

      # if this isn't the full packet,
      state =
        if ROS.Helpers.partial?(packet) do
          # put it as a partial packet
          Map.put(unquote(state), :partial, packet)
        else
          # take away the header that says the size of the message
          {_size, full_message} = Satchel.unpack_take(packet, :uint32)

          # call the function to do when the message has fully arrived
          full_message
          |> unquote(callback).()
          |> Map.delete(:partial)
        end

      # intended for `handle_info/2`
      {:noreply, state}
    end
  end

  # determines if a packet is not the whole message
  def partial?(packet) do
    {len, rest} = Satchel.unpack_take(packet, :uint32)

    String.length(rest) < len
  end

  # serialize a string. strings are preceeded by their length as a 32 bit
  # unsigned integer
  @spec pack_string(binary()) :: binary()
  def pack_string(str) do
    len_field =
      str
      |> String.length()
      |> Satchel.pack(:uint32)

    len_field <> str
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

  @spec module_to_type(atom()) :: String.t()
  def module_to_type(mod) when is_atom(mod) do
    [tail | rest] =
      mod
      |> Module.split()
      |> Enum.reverse()

    [tail | Enum.map(rest, &Macro.underscore/1)]
    |> Enum.reverse()
    |> Enum.join("/")
  end

  @spec type_to_module(String.t()) :: atom()
  def type_to_module(type) when is_binary(type) do
    type
    |> String.split("/")
    |> Enum.map(&Macro.camelize/1)
    |> List.insert_at(0, "Elixir")
    |> Enum.join(".")
    |> String.to_atom()
  end

  @spec underscore(String.t()) :: [String.t()]
  def underscore(module) do
    module
    |> String.split("/")
    |> Enum.map(&Macro.underscore/1)
  end

  @spec force_type(struct() | map(), module()) :: struct()
  def force_type(%type{} = data, type), do: data
  def force_type(%{} = data, type), do: struct(type, data)
end
