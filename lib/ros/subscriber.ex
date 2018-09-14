defmodule ROS.Subscriber do
  use DynamicSupervisor
  require Logger

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(opts) do
    {ip, port} = opts[:uri]

    # TODO: wait until this succeeds
    Logger.debug(fn ->
      inspect(
        Xenium.call!(
          ROS.SlaveApi.master_uri(),
          "registerPublisher",
          [
            Atom.to_string(opts[:node_name]),
            opts[:topic],
            opts[:type],
            "http://#{ip}:#{port}"
          ]
        )
      )
    end)

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec connect(
          atom() | pid(),
          (struct() -> any()),
          String.t(),
          pos_integer(),
          String.t()
        ) :: :ok
  def connect(subscriber, callback, ip, port, "TCPROS") do
    spec = {ROS.TCP, %{callback: callback}}

    {:ok, pid} = DynamicSupervisor.start_child(subscriber, spec)

    GenServer.call(pid, {:connect, ip, port})
  end
end
