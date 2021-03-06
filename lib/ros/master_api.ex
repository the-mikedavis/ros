defmodule ROS.MasterApi.Behaviour do
  @moduledoc false
  @callback make_call(String.t(), [String.t()], String.t()) :: [any()]
end

defmodule ROS.MasterApi do
  require Logger

  @behaviour __MODULE__.Behaviour
  @moduledoc false

  # The Master API formalized as functions.
  #
  # Function names take their lowercase form. Don't use this module. It's only
  # meant to be used in the underlying calls to setup publishers, subscribers,
  # and services.
  def lookup_node(caller_id \\ :noname, node_name) do
    make_call("lookupNode", [Atom.to_string(caller_id), node_name])
  end

  def lookup_service(service) do
    {ip, port} = service.uri

    make_call("lookupService", ["http://#{ip}:#{port}", service.service])
  end

  def get_published_topics(caller_id \\ :noname, sub_graph \\ "/") do
    make_call("getPublishedTopics", [Atom.to_string(caller_id), sub_graph])
  end

  def get_system_state(caller_id \\ :noname) do
    make_call("getSystemState", [Atom.to_string(caller_id)])
  end

  def get_uri(caller_id \\ :noname) do
    make_call("getUri", [Atom.to_string(caller_id)])
  end

  def request_topic(callerid, topic, transport, target) do
    make_call(
      "requestTopic",
      [callerid, ROS.Helpers.type(topic), transport],
      target
    )
  end

  def register_service(service, service_port) do
    {ip, port} = service.uri

    make_call("registerService", [
      Atom.to_string(service.node_name),
      service.service,
      "rosrpc://#{ip}:#{service_port}",
      "http://#{ip}:#{port}"
    ])
  end

  def register_publisher(pub) do
    {ip, port} = pub.uri

    make_call("registerPublisher", [
      Atom.to_string(pub.node_name),
      pub.topic,
      pub.type,
      "http://#{ip}:#{port}"
    ])
  end

  def register_subscriber(sub) do
    {ip, port} = sub.uri

    make_call("registerSubscriber", [
      Atom.to_string(sub.node_name),
      sub.topic,
      ROS.Helpers.type(sub.type),
      "http://#{ip}:#{port}"
    ])
  end

  @impl __MODULE__.Behaviour
  def make_call(name, args, target \\ ROS.SlaveApi.master_uri()) do
    Logger.debug(fn ->
      "Requesting: [\"#{name}\", #{inspect(args)}] from #{target}"
    end)

    call =
      case Xenium.call(target, name, args) do
        {:error, reason} ->
          raise "Error contacting ROS Master! Is `roscore` running? #{
                  inspect(reason)
                }"

        response ->
          response
      end

    call
    |> inspect()
    |> Logger.debug()

    call
  end
end
