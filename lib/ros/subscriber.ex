defmodule ROS.Subscriber do
  use DynamicSupervisor
  require Logger

  @moduledoc false

  def from_node_name(node_name, opts) do
    String.to_atom(Atom.to_string(node_name) <> "_" <> opts[:topic])
  end

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(opts) do
    ROS.MasterApi.register_subscriber(opts)

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec request(Keyword.t(), atom(), String.t(), String.t(), [[String.t()]]) ::
          :ok
  def request(sub, node_name, topic, publisher, [["TCPROS"]] = transport) do
    response =
      Xenium.call!(
        publisher,
        "requestTopic",
        [Atom.to_string(node_name), topic, transport]
      )

    [1, _, ["TCPROS", ip, port]] = response

    Logger.debug(fn -> inspect(response) end)

    connect(sub, ip, port, "TCPROS")
  end

  @spec connect(
          Keyword.t(),
          String.t(),
          pos_integer(),
          String.t()
        ) :: :ok
  def connect(subscriber, ip, port, "TCPROS") do
    spec = {ROS.TCP, %{sub: subscriber}}

    {:ok, pid} = DynamicSupervisor.start_child(subscriber[:name], spec)

    GenServer.cast(pid, {:connect, ip, port})
  end
end
