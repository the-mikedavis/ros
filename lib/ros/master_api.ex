defmodule ROS.MasterApi do
  require Logger

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
    {ip, port} = opts[:uri]

    make_call("registerPublisher", [
      Atom.to_string(opts[:node_name]),
      opts[:topic],
      opts[:type],
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
