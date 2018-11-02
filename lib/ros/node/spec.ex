defmodule ROS.Node.Spec do
  @spec node(atom(), [tuple()], Keyword.t()) ::
          {module(), {[tuple()], Keyword.t()}}
  def node(name, children \\ [], opts \\ []) do
    {ROS.Node, {children, opts ++ [name: name]}}
  end

  @spec publisher(atom(), String.t(), String.t() | module(), Keyword.t()) ::
          {module(), Keyword.t()}
  def publisher(name, topic, type, opts \\ []) do
    base_opts = [name: name, topic: topic, type: type]

    {ROS.Publisher, opts ++ base_opts}
  end

  @spec subscriber(
          String.t(),
          String.t() | module(),
          (struct() -> any()),
          Keyword.t()
        ) :: {module, Keyword.t()}
  def subscriber(topic, type, callback, opts \\ []) do
    base_opts = [topic: topic, type: type, callback: callback]

    {ROS.Subscriber, opts ++ base_opts}
  end

  @spec service_proxy(atom(), String.t(), String.t() | module(), Keyword.t()) ::
          {module(), Keyword.t()}
  def service_proxy(name, service, type, opts \\ []) do
    base_opts = [name: name, service: service, type: type]

    {ROS.Service.Proxy, opts ++ base_opts}
  end

  @spec service(String.t(), String.t() | module(), (struct() -> any()), Keyword.t()) :: {module(), Keyword.t()}
  def service(service, type, callback, opts \\ []) do
    base_opts = [service: service, type: type, callback: callback]

    {ROS.Service, opts ++ base_opts}
  end
end
