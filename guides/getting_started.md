# Getting Started

> Caution: this package is experimental and still under development. You should
> only use this package if you already have a firm grasp of the concepts of
> ROS.

This library provides an interface for interacting with other ROS nodes by
implementing the 4 major ROS abstractions:

- _Publisher_, an asynchronous message sender
- _Subscriber_, an asynchronous message consumer
- _Service_, a synchronous server which turns requests into responses
- _Service Proxy_, a synchronous requestor for services

At this time, this library does not support utilities like `rosrun`,
`roslaunch`, or `rospack`.

Most client libraries support these abstractions by creating objects, or
by simulating objects (in the case of Haskell). This library takes an alternate
approach. Each of the abstractions is instatiated as a process. The mapping is:

| ROS Abstraction | OTP Abstraction |
|-------------------|-------------------|
|Publisher          | Dynamic Supervisor |
|(TCP connections)  | GenServer |
|Subscriber         | GenServer |
|Service            | GenServer |
|Service Proxy      | GenServer |

In other client libraries, the ROS _Node_ can be confusing. Here, it's very
natural that the Node is a `Supervisor`. The Node gives names to its
subprocesses and handles XMLRPC requests for them from the ROS Master XMLRPC
Server.
