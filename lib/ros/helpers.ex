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
end
