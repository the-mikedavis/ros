defmodule ROS.MasterApi do
  def register_publisher(node_name, topic, definition, node_uri) do
    Xenium.call!(ROS.SlaveApi.get_master_uri(nil), "registerPublisher", [
      node_name,
      topic,
      definition,
      node_uri
    ])
  end
end
