defmodule ROS.Helpers do
  @moduledoc false

  # executes a `do` block once a full packet has been received; if it has
  # not been fully received, wait until the next call
  #
  # the do block must return `state`
  defmacro partial(packet, state, callback) do
    quote do
      partial = Map.get(unquote(state), :partial, "")
      packet = partial <> unquote(packet)

      state =
        if ROS.Helpers.partial?(packet) do
          Map.put(unquote(state), :partial, packet)
        else
          {_size, full_message} = Satchel.unpack_take(packet, :uint32)

          full_message
          |> unquote(callback).()
          |> Map.delete(:partial)
        end

      {:noreply, state}
    end
  end

  # determines if a packet is not the whole message
  def partial?(packet) do
    {len, rest} = Satchel.unpack_take(packet, :uint32)

    String.length(rest) < len
  end

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
end
