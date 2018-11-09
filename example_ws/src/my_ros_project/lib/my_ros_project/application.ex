defmodule MyRosProject.Application do
  @moduledoc false

  import ROS.Node.Spec
  require Logger

  use Application

  alias MyRosProject.{ChatterServer, AddTwoIntsServer}

  def start(_type, _args) do
    # add_two_ints = fn %{a: a, b: b} ->
    # Logger.debug(fn -> "[#{a} + #{b} = #{a + b}]" end)
    #
    # %{sum: a + b}
    # end

    children = [
      node(:"/mynode", [
        publisher(:talker, "/other_chatter", "std_msgs/Int16"),
        subscriber("/chatter", StdMsgs.String, ChatterServer),
        service_proxy(:myproxy, "/add_two_ints", "rospy_tutorials/AddTwoInts"),
        service("/add_two_ints", RospyTutorials.AddTwoInts, AddTwoIntsServer)
      ]),
      {ChatterServer, []},
      {AddTwoIntsServer, []}
    ]

    opts = [strategy: :one_for_one, name: MyRosProject.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
