# ROS - Elixir

Caution: this repo is still really heavily under development. I don't yet have
solutions for interoperability with `rosrun` or `roslaunch`. Please use only
for development purposes and curiosity only.

ROS Elixir is fully compatible with the regular way of making publishers,
subscribers, services, and service proxies. You can do so like so:

## Example Publisher

```elixir
use ROS

children = [
  node(:"/mynode", [
    publisher(:mypub, "chatter", "std_msgs/String")
  ])
]

Supervisor.start_link(children, strategy: :one_for_one)

for n <- 1..100 do
  Publisher.publish(:mypub, %StdMsgs.String{data: "This is my #{n}th message!"})
end
```

## Example Subscriber

```elixir
use ROS

callback = fn %StdMsgs.String{data: data} ->
  IO.puts(data)
end

children = [
  node(:"/mynode", [
    subscriber("chatter", "std_msgs/String", callback)
  ])
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Example Service

```elixir
use ROS

callback = fn %RospyTutorials.AddTwoInts.Request{a: a, b: b} ->
  %RospyTutorials.AddTwoInts.Response{sum: a + b}
end

children = [
  node(:"/mynode", [
    service("add_two_ints", "rospy_tutorials/AddTwoInts", callback)
  ])
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Example Service Proxy

```
use ROS

children = [
  node(:"/mynode", [
    service_proxy(:myproxy, "add_two_ints", "rospy_tutorials/AddTwoInts")
  ]
]

Supervisor.start_link(children, strategy: :one_for_one)

ServiceProxy.request(:myproxy, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4})
#=> {:ok, %RospyTutorials.AddTwoInts.Response{sum: 7}}
```

See the `example_ws` directory for an example app.
