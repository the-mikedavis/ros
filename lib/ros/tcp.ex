defmodule ROS.TCP do
  use GenServer
  use Private
  require Logger

  alias ROS.Message.ConnectionHeader, as: ConnHead

  # executes a `do` block once a full packet has been received; if it has
  # not been fully received, wait until the next call
  #
  # the do block must return `state`
  defmacrop partial(packet, state, do: execute) do
    quote do
      partial = Map.get(unquote(state), :partial, "")
      combined = partial <> unquote(packet)

      state =
        if partial?(combined) do
          Map.put(unquote(state), :partial, combined)
        else
          IO.inspect(combined, label: "combined", limit: :infinity)
          IO.inspect(String.length(combined), label: "|combined|", limit: :infinity)

          unquote(execute)
          |> Map.delete(:partial)
        end

      {:noreply, state}
    end
  end

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

  def handle_cast({:send, data}, %{socket: socket} = state)
      when is_binary(data) do
    :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  def handle_cast({:send, data}, %{socket: socket} = state) do
    :gen_tcp.send(socket, ROS.Message.serialize(data))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:tcp, _socket, packet}, %{init: true} = state) do
    partial packet, state do
      # TODO
      # combined
      # |> ROS.Message.ConnectionHeader.parse()
      # |> IO.inspect(label: "incoming connection header", limit: :infinity)

      Map.delete(state, :init)
    end
  end

  # for subscribers, send the connection header and then get data
  def handle_info({:tcp, _socket, packet}, %{sub: sub} = state) do
    partial packet, state do
      packet
      |> ROS.Message.deserialize(sub[:type])
      |> sub[:callback].()

      state
    end
  end

  # for publishers, parse the connection header
  def handle_info({:tcp, _socket, packet}, state) do
    partial packet, state do
      packet
      |> ROS.Message.ConnectionHeader.parse()
      |> IO.inspect(label: "incoming connection header", limit: :infinity)

      state
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warn("TCP connection closed")

    {:noreply, state}
  end

  private do
    defp build_conn_header(psub) do
      psub
      |> ConnHead.from()
      |> ConnHead.serialize()
    end

    # determines if a packet is not the whole message
    defp partial?(packet) do
      {len, rest} = Satchel.unpack_take(packet, :uint32)

      String.length(rest) < len
    end
  end
end
