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

    ConnHead.serialize(
      %ConnHead{
        callerid: sub[:node_name],
        topic: sub[:topic],
        type: sub[:type]
      }
    )

    data =
      <<178, 0, 0, 0, 37, 0, 0, 0, 99, 97, 108, 108, 101, 114, 105, 100, 61, 47, 108,
      105, 115, 116, 101, 110, 101, 114, 95, 57, 52, 56, 57, 95, 49, 53, 51, 54, 54,
      50, 54, 51, 55, 53, 53, 55, 52, 39, 0, 0, 0, 109, 100, 53, 115, 117, 109, 61,
      57, 57, 50, 99, 101, 56, 97, 49, 54, 56, 55, 99, 101, 99, 56, 99, 56, 98, 100,
      56, 56, 51, 101, 99, 55, 51, 99, 97, 52, 49, 100, 49, 31, 0, 0, 0, 109, 101,
      115, 115, 97, 103, 101, 95, 100, 101, 102, 105, 110, 105, 116, 105, 111, 110,
      61, 115, 116, 114, 105, 110, 103, 32, 100, 97, 116, 97, 10, 13, 0, 0, 0, 116,
      99, 112, 95, 110, 111, 100, 101, 108, 97, 121, 61, 48, 14, 0, 0, 0, 116, 111,
      112, 105, 99, 61, 47, 99, 104, 97, 116, 116, 101, 114, 20, 0, 0, 0, 116, 121,
      112, 101, 61, 115, 116, 100, 95, 109, 115, 103, 115, 47, 83, 116, 114, 105,
      110, 103>>

    GenServer.cast(self(), {:send, data})

    {:noreply, Map.put(state, :socket, socket)}
  end

  def handle_cast({:accept, port}, state) do
    {:ok, socket} = :gen_tcp.accept(port)

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
    |> ROS.Message.parse_as(sub[:type])
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
end
