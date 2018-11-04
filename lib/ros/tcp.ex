defmodule ROS.TCP do
  use GenServer
  require Logger

  @moduledoc false

  alias ROS.Message.ConnectionHeader, as: ConnHead
  alias ROS.Helpers
  import Helpers, only: [partial: 3]
  import Elixir.Kernel, except: [send: 2]

  # send a message on a socket
  #
  # really just calls `:gen_tcp.send/2`, but is re-ordered to making piping
  # easier.
  @spec send(binary() | struct(), :gen_tcp.socket()) :: :ok
  def send(data, socket) when is_binary(data), do: :gen_tcp.send(socket, data)

  def send(%_struct_module{} = data, socket) do
    data
    |> ROS.Message.serialize()
    |> send(socket)
  end

  ## Server API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    {:ok, Map.put(args, :init, true)}
  end

  @impl GenServer
  def handle_call(:accept, _from, state) do
    {:ok, socket} =
      :gen_tcp.listen(0, [:binary, reuseaddr: true, active: true, packet: 0])

    {:ok, port_number} = :inet.port(socket)

    GenServer.cast(self(), {:accept, socket})

    {:reply, port_number, Map.put(state, :socket, socket)}
  end

  @impl GenServer
  def handle_cast({:accept, port}, %{pub: pub} = state) do
    {:ok, socket} = :gen_tcp.accept(port)

    :ok =
      pub
      |> ConnHead.from()
      |> ConnHead.serialize()
      |> send(socket)

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:send, data}, %{socket: socket, pub: pub} = state) do
    data
    |> Helpers.force_type(Helpers.module(pub.type))
    |> send(socket)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:tcp, _socket, packet}, %{init: true} = state) do
    partial(packet, state, fn full_message ->
      full_message
      |> ROS.Message.ConnectionHeader.parse()

      # TODO do something with the connection header, like checking the md5sum

      Map.delete(state, :init)
    end)
  end

  def handle_info({:tcp_closed, socket}, state) do
    Logger.debug(fn -> "TCP connection closed" end)

    :gen_tcp.close(socket)

    {:noreply, state}
  end
end
