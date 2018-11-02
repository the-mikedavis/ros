defmodule ROS.Application do
  @moduledoc false

  # TODO: remove once this is reproducible

  use Application
  import ROS.Node.Spec

  def start(_type, _args) do
    _add_two_ints = fn x, y ->
      IO.inspect(x, label: "x")
      IO.inspect(y, label: "y")

      %RospyTutorials.AddTwoInts.Response{sum: x + y}
    end

    children = [
      # node(:"/mynode", [publisher(:talker, "/chatter", "std_msgs/Int16")])
      node(:"/mynode", [
        #subscriber("/chatter", "std_msgs/Int32MultiArray", &IO.inspect/1)
        service_proxy(:proximus, "/add_two_ints", "rospy_tutorials/AddTwoInts")
        # service("/add_two_ints", "rospy_tutorials/AddTwoInts", add_two_ints)
      ])
    ]

    opts = [strategy: :one_for_one, name: ROS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
