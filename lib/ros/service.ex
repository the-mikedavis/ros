defmodule ROS.Service do
  use Supervisor
  require Logger

  import ROS.Helpers, only: [pack_string: 1]

  def from_node_name(node_name, opts) do
    String.to_atom(Atom.to_string(node_name) <> "_" <> opts[:service])
  end

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    [{ROS.TCP, %{srv: opts}}]
    |> Supervisor.init(strategy: :one_for_one)
  end

  @spec serialize(struct()) :: binary()
  def serialize(%ROS.Service.Error{message: msg}) do
    Satchel.pack(0, :uint8) <> pack_string(msg)
  end

  def serialize(msg) do
    Satchel.pack(1, :uint8) <> pack_string(ROS.Message.serialize(msg))
  end

  @spec deserialize_response(binary(), binary() | module()) :: {:ok, struct()} | {:error, String.t()}
  def deserialize_response(data, type) when is_binary(type) do
    deserialize_response(data, ROS.Message.module(type))
  end
  def deserialize_response(data, type) do
    {status_code, rest} = Satchel.unpack_take(data, :uint8)

    case status_code do
      1 ->
        type = Module.concat(type, Response)

        {:ok, ROS.Message.deserialize(rest, type)}

      0 -> {:error, Bite.drop(rest, 4)}
    end
  end
end
