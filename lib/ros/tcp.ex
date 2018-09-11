defmodule ROS.TCP do
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
end
