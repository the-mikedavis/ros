defmodule ROS.TCP do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    {:ok, args}
  end

  def handle_call(:spawn, _from, state) do
    {:ok, port} =
      :gen_tcp.listen(0, [:binary, reuseaddr: true, active: true, packet: 0])

    {:ok, port_number} = :inet.port(port)

    GenServer.cast(self(), {:accept, port})

    {:reply, port_number, state}
  end

  def handle_cast({:accept, port}, state) do
    {:ok, _socket} = :gen_tcp.accept(port)

    {:noreply, state}
  end

  def handle_cast({:send, data}, state) do
    # TODO: serialize data and send

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, packet}, state) do
    packet
    |> ROS.Message.parse()
    |> IO.inspect(label: "incoming message", limit: :infinity)

    {:noreply, state}
  end
end
