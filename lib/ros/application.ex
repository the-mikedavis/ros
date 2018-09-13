defmodule ROS.Application do
  @moduledoc false

  # TODO: remove once this is reproducible

  use Application

  def start(_type, _args) do
    children = [
      {ROS.Node, [name: :mynode]}
    ]

    opts = [strategy: :one_for_one, name: ROS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
