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
  def init(opts) do
    {ip, port} = opts[:uri]

    # TODO: wait until this succeeds
    Logger.debug(fn ->
      inspect(
        Xenium.call!(
          ROS.SlaveApi.master_uri(),
          "registerSubscriber",
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

  @spec request(Keyword.t(), atom(), String.t(), String.t(), [[String.t()]]) :: :ok
  def request(sub, node_name, topic, publisher, [["TCPROS"]] = transport) do
    response =
      Xenium.call!(
        publisher,
        "requestTopic",
        [Atom.to_string(node_name), topic, transport]
      )

    [1, _, ["TCPROS", ip, port]] = response

    Logger.debug(fn -> inspect(response) end)

    connect(sub[:name], sub[:callback], ip, port, "TCPROS")
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

    GenServer.cast(pid, {:connect, ip, port})
  end
end
