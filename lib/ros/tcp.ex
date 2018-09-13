defmodule ROS.TCP do
  use GenServer

  @doc "Allocate a free port."
  @spec allocate_port!() :: {port(), pos_integer()}
  def allocate_port! do
    {:ok, port} = :gen_tcp.listen(0, [:binary, reuseaddr: true, active: false])

    port
  end

  def listen(port_number) do
    {:ok, port} =
      :gen_tcp.listen(port_number, [:binary, reuseaddr: true, active: true])

    {:ok, client} = :gen_tcp.accept(port)
    # IO.inspect(:gen_tcp.recv(client, 0))
    :ok = :gen_tcp.controlling_process(client, Process.whereis(ROS.Publisher))
  end

  ## ---------------------- ##

  def init(args) do
    {:ok, port} =
      :gen_tcp.listen(0, [:binary, reuseaddr: true, active: true, packet: 0])

    {:ok, port_number} = :inet.port(port)

    GenServer.cast(self(), {:accept, port})

    {:ok, args}
  end

  def handle_call({:spawn, _caller_id, _topic}, _from, state) do
    {:ok, port} =
      :gen_tcp.listen(0, [:binary, reuseaddr: true, active: true, packet: 0])

    {:ok, port_number} = :inet.port(port)

    GenServer.cast(__MODULE__, {:accept, port})

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
