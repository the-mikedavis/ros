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
    MasterApi.register_publisher(opts)

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec connect(Keyword.t(), String.t()) :: non_neg_integer()
  def connect(publisher, "TCPROS") do
    spec = {ROS.TCP, %{pub: publisher}}

    {:ok, pid} = DynamicSupervisor.start_child(publisher[:name], spec)

    GenServer.call(pid, :accept)
  end

  def publish(publisher, message) do
    # Broadcast the message to all open connections
    publisher
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _type, _module} ->
      GenServer.cast(pid, {:send, message})
    end)
  end
end
