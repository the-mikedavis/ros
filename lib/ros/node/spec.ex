defmodule ROS.Node.Spec do
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
    {ROS.Subscriber, %ROS.Subscriber{topic: topic, type: type, callback: callback}}
  end

  @spec service_proxy(atom(), String.t(), String.t() | module()) ::
          {module(), %ROS.Service.Proxy{}}
  def service_proxy(name, service, type) do
    {ROS.Service.Proxy, %ROS.Service.Proxy{name: name, service: service, type: type}}
  end

  @spec service(String.t(), String.t() | module(), (struct() -> any())) :: {module(), %ROS.Service{}}
  def service(service, type, callback) do
    {ROS.Service, %ROS.Service{service: service, type: type, callback: callback}}
  end
end
