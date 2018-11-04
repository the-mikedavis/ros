defmodule MyRosProject.Application do
  @moduledoc false

  import ROS.Node.Spec

  use Application

  def start(_type, _args) do
    add_two_ints = fn %RospyTutorials.AddTwoInts.Request{a: a, b: b} ->
      Logger.debug(fn -> "[#{a} + #{b} = #{a + b}]" end)
      %RospyTutorials.AddTwoInts.Response{sum: a + b}
    end

    children = [
      node(:"/mynode", [
        publisher(:talker, "/other_chatter", "std_msgs/Int16")
        subscriber("/chatter", "std_msgs/Int32MultiArray", &IO.inspect/1)
        service_proxy(:proximus, "/add_two_ints", "rospy_tutorials/AddTwoInts")
        service("/add_two_ints", "rospy_tutorials/AddTwoInts", add_two_ints)
      ])
    ]

    opts = [strategy: :one_for_one, name: MyRosProject.Supervisor]
    Supervisor.start_link(children, opts)
  end
end