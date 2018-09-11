defmodule ROS.Publisher do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(args), do: {:ok, args}

  @spec register(String.t(), String.t()) :: integer()
  def register(caller_id, topic) do
    GenServer.call(__MODULE__, {:spawn, caller_id, topic})
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

  def handle_info({:tcp, _socket, packet}, state) do
    # IO.inspect(packet, label: "incoming packet", limit: :infinity)
    IO.inspect(ROS.Message.parse(packet))

    {:noreply, state}
  end
end
