defmodule ROS.MasterApi do
  require Logger

  @moduledoc false

  # The Master API formalized as functions.
  #
  # Function names take their lowercase form. Don't use this module. It's only
  # meant to be used in the underlying calls to setup publishers, subscribers,
  # and services.

  def lookup_service(opts) do
    {ip, port} = opts[:uri]

    make_call("lookupService", ["http://#{ip}:#{port}", opts[:service]])
  end

  def register_service(service, service_port) do
    {ip, port} = service[:uri]

    make_call("registerService", [
      Atom.to_string(service[:node_name]),
      service[:service],
      "rosrpc://#{ip}:#{service_port}",
      "http://#{ip}:#{port}"
    ])
  end

  def register_publisher(pub) do
    {ip, port} = pub[:uri]

    make_call("registerPublisher", [
      Atom.to_string(pub[:node_name]),
      pub[:topic],
      pub[:type],
      "http://#{ip}:#{port}"
    ])
  end

  def register_subscriber(sub) do
    {ip, port} = sub[:uri]

    make_call("registerSubscriber", [
      Atom.to_string(sub[:node_name]),
      sub[:topic],
      sub[:type],
      "http://#{ip}:#{port}"
    ])
  end

  defp make_call(name, args) do
    call =
      ROS.SlaveApi.master_uri()
      |> Xenium.call!(name, args)

    call
    |> inspect()
    |> Logger.debug()

    call
  end
end
