defmodule ROS.Node.Spec do
  @moduledoc """
  A set of functions for declaring ROS abstractions for your Supervisor setup.

  Add ROS abstractions to your `lib/my_project/application.ex` like so:

      iex> import ROS.Node.Spec
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
      iex> {ok?, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      iex> ok?
      :ok

  Note that you can also write any ROS types in their module form after you've
  compiled them with `mix genmsg` or `mix gensrv`

      iex> import ROS.Node.Spec
      iex> publisher(:mypub, "chatter", StdMsgs.String)
      {ROS.Publisher, %ROS.Publisher{name: :mypub, topic: "chatter", type: StdMsgs.String}}
      iex> service_proxy(:myproxy, "add_two_ints", RospyTutorials.AddTwoInts)
      {ROS.Service.Proxy, %ROS.Service.Proxy{name: :myproxy, service: "add_two_ints", type: RospyTutorials.AddTwoInts}}
  """

  @typedoc """
  An identifier for something that listens to messages received by a subscriber
  or service. Follow the naming conventions of GenServer.
  """
  @type listener() :: atom() | pid()

  @doc """
  Creates a child spec for a node.

  A node is the ROS equivalent of a Supervisor. You should group your
  publishers, subscribers, services, and service proxies as children of the
  node. Nodes also startup hidden processes like a Slave API server and an
  XML-RPC server for interacting with ROS master.
  """
  @spec node(atom(), [tuple()]) :: {module(), %ROS.Node{}}
  def node(name, children \\ []) do
    {ROS.Node, %ROS.Node{children: children, name: name}}
  end

  @doc """
  Creates a child spec for a publisher process.

  ## Parameters

  - `name` an atom or reference to call the publisher. This will allow you to
  call the publisher by name later when making a call to
  `ROS.Publisher.publish/2`.
  - `topic` the ROS topic to listen to
  - `type` the msg type expected in that topic. Either string format
  ("std_msgs/Int16") or module format `StdMsgs.Int16` are accepted.
  """
  @spec publisher(atom(), String.t(), String.t() | module()) ::
          {module(), %ROS.Publisher{}}
  def publisher(name, topic, type) do
    {ROS.Publisher, %ROS.Publisher{name: name, topic: topic, type: type}}
  end

  @doc """
  Creates a child spec for a subscriber process.

  ## Parameters

  - `topic` the ROS topic to listen to
  - `type` the msg type expected in that topic.
  Either string format ("std_msgs/Int16") or module format `StdMsgs.Int16` are accepted.

  The third parameter can either be a callback function, a pid or atom name,
  or list of pids/atom names.

  If it's a callback, that callback function will be executed every time the
  subscriber receives a new message. This function call will be blocking, but
  the GenServer that the subscriber is running on will buffer incoming
  messages, so each callback call will be in order. This behavior is meant
  to most closely simulate the bahavior of the Python and C++ client library
  behaviors.

  If it's a pid or atom, the subscriber process will send a `cast` message
  to that pid or atom using `GenServer.cast/2` containing
  `{:subscription, :from_subscriber_proc_name, %<incoming-message-type>{}}`
  (e.g. `{:subscription, :from_subscriber_proc_name, %StdMsgs.String{data: "hello world"}}`).
  Due to the behavior of `cast`, messages should arrive in order.

  If it's a list of pids or atoms, the subscriber process will send a `cast`
  message as described above to each of the processes in the list. There is
  no garuantee about order in sending to each process.

  ## Examples

  ```
  import ROS.Node.Spec
  children = [node(:mynode, [
    subscriber("chatter", "std_msgs/String", &IO.inspect/1),
    subscriber("other_chatter", "std_msgs/String", self()),
    subscriber("another_chatter", "std_msgs/String", MyModule.ChatterServer)
  ])]
  Supervisor.start_link(children)
  flush()
  # => {:"$gen_cast", {:subscription, :mynode_other_chatter, %StdMsgs.String{data: "hello world"}}}
  ```

  If you're attaching a GenServer to the subscriber, you'll need to provide
  a handle for the subscription:

  ```
  defmodule MyModule.ChatterServer do
    use GenServer

    def start_link(_otps), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

    def init(args), do: {:ok, args}

    def handle_cast({:subscription, _from, %StdMsgs.String{data: data}}, state) do
      # do something interesting with `data`

      {:noreply, state}
    end
  end
  ```

  The subscriber will send its process name (an atom) in the `cast` tuple. This
  is so that you can differentiate between different subscribers of the same type
  if you're listening to multiple subscriber processes. This is a small use case,
  though. For common use, you should underscore the process name as shown above.
  """
  @spec subscriber(
          String.t(),
          String.t() | module(),
          (struct() -> any()) | listener() | [listener()]
        ) :: {module(), %ROS.Subscriber{}}
  def subscriber(topic, type, callback) when is_function(callback) do
    {ROS.Subscriber,
     %ROS.Subscriber{topic: topic, type: type, callback: callback}}
  end

  def subscriber(topic, type, listener)
      when is_pid(listener) or is_atom(listener) do
    {ROS.Subscriber,
     %ROS.Subscriber{topic: topic, type: type, listeners: [listener]}}
  end

  def subscriber(topic, type, listeners) when is_list(listeners) do
    {ROS.Subscriber,
     %ROS.Subscriber{topic: topic, type: type, listeners: listeners}}
  end

  @doc """
  Creates a child spec for a service proxy process.
  """
  @spec service_proxy(atom(), String.t(), String.t() | module()) ::
          {module(), %ROS.Service.Proxy{}}
  def service_proxy(name, service, type) do
    {ROS.Service.Proxy,
     %ROS.Service.Proxy{name: name, service: service, type: type}}
  end

  @doc """
  Creates a child spec for a service process.

  ## Parameters

  - `service` the ROS service name to listen to
  - `type` the srv type expected in that topic.
  Either string format ("std_srv/Bool") or module format `StdMsgs.Bool` are
  accepted.

  The third parameter can either be a callback function a pid or atom name.

  If it's a function, that function will be executed and the return value
  will be sent as a service response. If it's a pid or atom, the request
  will be forwarded to that process using `GenServer.call/2`. The reply value
  from the `call` will be sent to the requestor as a service response.
  There may only be one listener for services.

  Each `call` sent to the listener will take the form of
  `{:service, %<service-type>.Request{}}`. (e.g.
  `{:service, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4}}`).
  """
  @spec service(
          String.t(),
          String.t() | module(),
          (struct() -> any()) | listener() | [listener()]
        ) :: {module(), %ROS.Service{}}
  def service(service, type, callback) when is_function(callback) do
    {ROS.Service,
     %ROS.Service{service: service, type: type, callback: callback}}
  end

  def service(service, type, listener)
      when is_pid(listener) or is_atom(listener) do
    {ROS.Service,
     %ROS.Service{service: service, type: type, listener: listener}}
  end
end
