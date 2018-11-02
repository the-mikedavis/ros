defmodule ROS.Message.ConnectionHeader do
  use Private

  @moduledoc """
  Connection Headers proceed messages and provides a standard format
  for reading and understanding messages.
  """

  @type t :: %__MODULE__{
          callerid: String.t(),
          topic: String.t(),
          service: String.t(),
          md5sum: String.t(),
          type: String.t() | struct(),
          message_definition: String.t(),
          error: String.t(),
          persistent: boolean(),
          tcp_nodelay: boolean(),
          latching: boolean(),
          probe: boolean()
        }

  defstruct callerid: nil,
            topic: nil,
            service: nil,
            md5sum: nil,
            type: nil,
            message_definition: nil,
            error: nil,
            persistent: false,
            tcp_nodelay: false,
            latching: false,
            probe: false

  def into(fields) do
    map =
      fields
      |> Enum.map(&translate/1)
      |> Enum.into(%{})

    struct(__MODULE__, map)
  end

  @spec parse(binary()) :: %__MODULE__{}
  def parse(packet) do
    packet
    |> ROS.Message.split()
    |> into()
  end

  def serialize(%__MODULE__{type: type} = conn_header) when is_binary(type) do
    packet =
      conn_header
      |> Map.from_struct()
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)
      |> Enum.map(&serialize_field/1)
      |> Enum.map(fn field -> field_length_binary(field) <> field end)
      |> Enum.reduce(&<>/2)

    field_length_binary(packet) <> packet
  end

  def serialize(%__MODULE__{type: type} = conn_header) when is_atom(type) do
    serialize(%__MODULE__{conn_header | type: ROS.Message.type(type)})
  end

  @doc """
  Generate a connection header from a subscriber or publisher keyword list.
  """
  @spec from(Keyword.t()) :: %__MODULE__{}
  def from(opts) do
    type = ROS.Message.module(opts[:type])

    kwlist =
      [
        type: type,
        md5sum: type.md5sum(),
        message_definition: type.definition(),
        callerid: Atom.to_string(opts[:node_name])
      ] ++ opts

    struct(__MODULE__, kwlist)
  end

  private do
    defp translate("tcp_nodelay=0"), do: {:tcp_nodelay, false}
    defp translate("tcp_nodelay=1"), do: {:tcp_nodelay, true}
    defp translate("persistent=0"), do: {:persistent, false}
    defp translate("persistent=1"), do: {:persistent, false}
    defp translate("latching=0"), do: {:latching, false}
    defp translate("latching=1"), do: {:latching, false}
    defp translate("probe=0"), do: {:probe, false}
    defp translate("probe=1"), do: {:probe, true}

    defp translate(field) do
      [lhs, rhs] = String.split(field, "=", parts: 2)

      {String.to_atom(lhs), rhs}
    end

    defp serialize_field({key, true})
         when key in [:tcp_nodelay, :persistent, :latching, :probe] do
      Atom.to_string(key) <> "=" <> "1"
    end

    defp serialize_field({key, false})
         when key in [:tcp_nodelay, :persistent, :latching, :probe] do
      Atom.to_string(key) <> "=" <> "0"
    end

    defp serialize_field({key, value}) do
      Atom.to_string(key) <> "=" <> value
    end

    @spec field_length_binary(binary()) :: binary()
    defp field_length_binary(field) do
      field
      |> String.length()
      |> Satchel.pack(:uint32)
    end
  end
end
