defmodule ROS.LocalParameterServer do
  use Agent

  @doc false
  def start_link(_opts), do: Agent.start_link(&Map.new/0, name: __MODULE__)

  @doc "Update the list of publishers registered to a topic"
  @spec update_publisher_list(String.t(), [String.t()]) :: :ok
  def update_publisher_list(topic, publishers) do
    Agent.update(__MODULE__, fn state ->
      put_in(state[:publishers][topic], publishers)
    end)
  end
end
