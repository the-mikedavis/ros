defmodule ROS.Node do
  use Supervisor

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    children = Keyword.get(opts, :children, [])

    hidden_procs = [
      # the XMLRPC server
      {ROS.XMLRPCServer, opts}
    ]

    Supervisor.start_link(__MODULE__, children ++ hidden_procs, name: name)
  end

  @impl Supervisor
  def init(children) do
    Supervisor.init(children, strategy: :one_for_one)
  end
end
