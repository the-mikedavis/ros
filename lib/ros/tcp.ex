defmodule ROS.TCP do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    {:ok, args}
  end

  @impl GenServer
  def handle_call(:accept, _from, state) do
    {:ok, port} =
      :gen_tcp.listen(0, [:binary, reuseaddr: true, active: true, packet: 0])

    {:ok, port_number} = :inet.port(port)

    GenServer.cast(self(), {:accept, port})

    {:reply, port_number, state}
  end

  @impl GenServer
  def handle_cast({:connect, ip, port}, state) do
    ip_addr =
      ip
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()

    {:ok, socket} = :gen_tcp.connect(ip_addr, port, packet: 0)

    :ok = :gen_tcp.controlling_process(socket, self())

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:accept, port}, state) do
    {:ok, socket} = :gen_tcp.accept(port)

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:send, _data}, state) do
    # TODO: serialize data and send

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:tcp, _socket, packet}, state) do
    packet
    |> ROS.Message.parse()
    |> IO.inspect(label: "incoming message", limit: :infinity)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warn("TCP connection closed")

    {:noreply, state}
  end
end
