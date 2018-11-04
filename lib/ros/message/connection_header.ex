defmodule ROS.Message.ConnectionHeader do
  use Private
  alias ROS.Helpers

  @moduledoc false
  # Connection Headers proceed messages and provides a standard format
  # for reading and understanding messages. Users will never have to handle
  # connection headers. These are just exchanged between pubs/subs and
  # srvs/srv_prxs.
  #
  # if you're curious as to what's going on under the hood, this is probably
  # one of the easiest to read modules

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

  # turn a binary that came in from some external pub/sub/srv/srv_prx and
  # turn in into a connection header struct
  @spec parse(binary()) :: %__MODULE__{}
  def parse(packet) do
    kwlist =
      packet
      |> ROS.Message.split()
      |> Enum.map(&translate/1)

    # turn the list of fields into a connection header struct
    struct(__MODULE__, kwlist)
  end

  # different from `ROS.Message.serialize/1` because it only serializes the
  # fields present, and all fields are strings
  def serialize(%__MODULE__{type: type} = conn_header) when is_binary(type) do
    conn_header
    |> Map.from_struct()
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.map(&serialize_field/1)
    |> Enum.map(&Helpers.pack_string/1)
    |> Enum.reduce(&<>/2)
    |> Helpers.pack_string()
  end

  def serialize(%__MODULE__{type: type} = conn_header) when is_atom(type) do
    serialize(%__MODULE__{conn_header | type: Helpers.type(type)})
  end

  # Generate a connection header from a subscriber or publisher keyword list.
  @spec from(struct()) :: %__MODULE__{}
  def from(opts) do
    type = Helpers.module(opts.type)

    kwlist = [
      type: type,
      md5sum: type.md5sum(),
      message_definition: type.definition(),
      callerid: Atom.to_string(opts.node_name)
    ]

    struct(__MODULE__, [topic_or_service(opts) | kwlist])
  end

  private do
    # give the right field based on the struct we're dealing with
    #
    # pubs/subs -> topic field
    # srvs/srv_prxs -> service field
    @spec topic_or_service(struct()) :: {atom(), String.t()}
    defp topic_or_service(%{topic: topic}), do: {:topic, topic}
    defp topic_or_service(%{service: service}), do: {:service, service}

    # these are hard-coded because i don't wanna deal with parsing bits
    # as booleans, and no one uses bits as booleans in elixir (because
    # 0 is not falsey)
    @spec translate(String.t()) :: {atom(), boolean() | String.t()}
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

    @spec serialize_field({atom(), boolean() | String.t()}) :: binary()
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
  end
end
