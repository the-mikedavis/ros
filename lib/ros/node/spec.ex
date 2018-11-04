defmodule ROS.Node.Spec do
  @moduledoc """
  A set of functions for declaring ROS abstractions for your Supervisor setup.

  Add ROS abstractions to your `lib/my_project/application.ex` like so:

      iex> children = [
      ...>   node(:"/mynode", [
      ...>     publisher(:mypub, "chatter", "std_msgs/String"),
      ...>     subscriber("other_chatter", "std_msgs/Int16", &IO.inspect/1),
      ...>     service_proxy(:myproxy, "add_two_ints", "rospy_tutorials/AddTwoInts"),
      ...>     service("add_two_ints", "rospy_tutorials/AddTwoInts", fn %RospyTutorials.AddTwoInts.Request{a: a, b: b} ->
      ...>       %RospyTutorials.AddTwoInts.Response{sum: a + b}
      ...>     end)
      ...>   ])
      ...> ]
      iex> Supervisor.start_link(children, strategy: :one_for_one)

  Note that you can also write any ROS types in their module form after you've
  compiled them with `mix genmsg` or `mix gensrv`

      iex> publisher(:mypub, "chatter", StdMsgs.String)
      iex> service_proxy(:myproxy, "add_two_ints", RospyTutorials.AddTwoInts)
  """

  @spec node(atom(), [tuple()]) :: {module(), %ROS.Node{}}
  def node(name, children \\ []) do
    {ROS.Node, %ROS.Node{children: children, name: name}}
  end

  @spec publisher(atom(), String.t(), String.t() | module()) ::
          {module(), %ROS.Publisher{}}
  def publisher(name, topic, type) do
    {ROS.Publisher, %ROS.Publisher{name: name, topic: topic, type: type}}
  end

  @spec subscriber(String.t(), String.t() | module(), (struct() -> any())) ::
          {module(), %ROS.Subscriber{}}
  def subscriber(topic, type, callback) do
    {ROS.Subscriber,
     %ROS.Subscriber{topic: topic, type: type, callback: callback}}
  end

  @spec service_proxy(atom(), String.t(), String.t() | module()) ::
          {module(), %ROS.Service.Proxy{}}
  def service_proxy(name, service, type) do
    {ROS.Service.Proxy,
     %ROS.Service.Proxy{name: name, service: service, type: type}}
  end

  @spec service(String.t(), String.t() | module(), (struct() -> any())) ::
          {module(), %ROS.Service{}}
  def service(service, type, callback) do
    {ROS.Service,
     %ROS.Service{service: service, type: type, callback: callback}}
  end
end
