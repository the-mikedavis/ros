defmodule ROS.SlaveApi do
  # @behaviour __MODULE__.Behaviour

  alias ROS.LocalParameterServer, as: ParamServer

  @moduledoc """
  An implementation of the ROS Slave API Behaviour from
  `ROS.SlaveApi.Behaviour`.

  Note that, as a change from the Slave API as defined
  [at the ROS wiki](http://wiki.ros.org/ROS/Slave_API), all of these functions
  are underscore notation. This sacrifices a small amount of consistency for
  the sake of the Elixir style guide.
  """

  def get_master_uri(_caller_id), do: System.get_env("ROS_MASTER_URI")

  def publisher_update("/master", topic, publisher_list) do
    ParamServer.update_publisher_list(topic, publisher_list)

    [1, "publisher list for #{topic} updated.", 0]
  end

  def request_topic(caller_id, topic, [["TCPROS"]]) do
    # TODO: allocate a publisher
    ip = ROS.Node.get_ip()
    port_number = 666

    [1, "ready on #{ip}:#{port_number}", ["TCPROS", ip, port_number]]
  end
end
