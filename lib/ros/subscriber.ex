defmodule ROS.Subscriber do
  use DynamicSupervisor
  require Logger

  def from_node_name(node_name, opts) do
    String.to_atom(Atom.to_string(node_name) <> "_" <> opts[:topic])
  end

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def request(node_name, topic, publisher, [["TCPROS"]] = transport) do
    Logger.debug(fn ->
      inspect(
        Xenium.call!(
          publisher,
          "requestTopic",
          [node_name, topic, transport]
        )
      )
    end)
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
