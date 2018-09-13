defmodule ROS.Application do
  @moduledoc false

  # TODO: remove once this is reproducible

  use Application
  import ROS.Node.Spec

  def start(_type, _args) do
    children = [
      node(:mynode, [publisher(:mypublisher, "/chatter", "std_msgs/String")])
    ]

    opts = [strategy: :one_for_one, name: ROS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
