defmodule ROS.Application do
  @moduledoc false

  # TODO: remove once this is reproducible

  use Application
  import ROS.Node.Spec

  def start(_type, _args) do
    children = [
      node(:"/mynode", [publisher(:talker, "/chatter", "std_msgs/Int16")])
      # node(:"/mynode", [
      # subscriber("/chatter", "std_msgs/Float32", &IO.inspect/1)
      # ])
    ]

    opts = [strategy: :one_for_one, name: ROS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
