defmodule ROS.Publisher do
  use DynamicSupervisor
  require Logger

  @moduledoc """
  A ROS Publisher is a sender in asynchronous, one-to-many communication.

  ROS Publishers are best modeled by OTP Dynamic Supervisors. Dynamic
  Supervisors allow spawning of child processes on demand, which is perfect
  because a ROS Subscriber node can connect to any publisher on demand
  (depending on when it is spun up).
  """

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

  @spec connect(atom() | pid(), String.t()) :: pos_integer()
  def connect(publisher, "TCPROS") do
    spec = {ROS.TCP, []}

    {:ok, pid} = DynamicSupervisor.start_child(publisher, spec)

    GenServer.call(pid, :accept)
  end

  def send(publisher, message) do
    # Broadcast the message to all open connections
    publisher
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _type, _module} ->
      GenServer.cast(pid, {:send, message})
    end)
  end
end
