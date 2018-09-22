defmodule ROS.TCP do
  use GenServer
  require Logger

  alias ROS.Message.ConnectionHeader, as: ConnHead

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    {:ok, args}
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
  def handle_cast({:connect, ip, port}, %{sub: sub} = state) do
    ip_addr =
      ip
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()

    {:ok, socket} = :gen_tcp.connect(ip_addr, port, [:binary, packet: 0])

    :ok = :gen_tcp.controlling_process(socket, self())

    data = build_conn_header(sub)

    GenServer.cast(self(), {:send, data})

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:accept, port}, %{pub: pub} = state) do
    {:ok, socket} = :gen_tcp.accept(port)

    data = build_conn_header(pub)

    GenServer.cast(self(), {:send, data})

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:send, data}, %{socket: socket} = state) do
    :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  @impl GenServer
  # for subscribers, send the connection header and then get data
  def handle_info({:tcp, _socket, packet}, %{sub: sub} = state) do
    packet
    |> ROS.Message.deserialize(sub[:type])
    |> sub[:callback].()

    {:noreply, state}
  end

  # for publishers, parse the connection header
  def handle_info({:tcp, _socket, packet}, state) do
    packet
    |> ROS.Message.ConnectionHeader.parse()
    |> IO.inspect(label: "incoming connection header", limit: :infinity)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warn("TCP connection closed")

    {:noreply, state}
  end

  defp build_conn_header(psub) do
    psub
    |> ConnHead.from()
    |> ConnHead.serialize()
  end
end
