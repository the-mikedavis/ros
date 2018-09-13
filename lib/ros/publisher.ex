defmodule ROS.Publisher do
  use DynamicSupervisor

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
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def connect(publisher, caller_id, topic, type, "ROSTCP") do
    spec = {ROS.TCP, name: caller_id, topic: topic, type: type}

    DynamicSupervisor.start_child(publisher, spec)
  end

  def send(publisher, message) do
    publisher
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _type, _module} ->
      GenServer.cast(pid, {:send, message})
    end)
  end
end
