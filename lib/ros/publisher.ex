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

  # don't use the struct! internal use only!

  @enforce_keys [:name, :topic, :type]
  defstruct @enforce_keys ++ [:node_name, :uri]

  @doc false
  def start_link(pub) do
    DynamicSupervisor.start_link(__MODULE__, pub, name: pub.name)
  end

  @doc false
  @impl DynamicSupervisor
  def init(pub) do
    ROS.MasterApi.register_publisher(pub)

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # used to start a new connection when a subscriber asks to hear from the
  # publisher
  @doc false
  @spec connect(%ROS.Publisher{}, String.t()) :: non_neg_integer()
  def connect(publisher, "TCPROS") do
    spec = {ROS.TCP, %{pub: publisher}}

    {:ok, pid} = DynamicSupervisor.start_child(publisher.name, spec)

    GenServer.call(pid, :accept)
  end

  @doc """
  Publish a message from a publisher.

  This is asynchronous. A list of :ok atoms will be received, one for each
  TCP connection to the publisher.

  ## Examples

      iex> ROS.Publisher.publish(:mypub, %StdMsgs.String{data: "hello!"})
      [:ok]
  """
  @spec publish(atom(), struct()) :: [:ok]
  def publish(publisher, message) do
    # Broadcast the message to all open connections
    publisher
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _type, _module} ->
      GenServer.cast(pid, {:send, message})
    end)
  end
end
