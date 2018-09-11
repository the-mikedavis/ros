defmodule ROS.Node do
  use Agent

  @moduledoc """
  Helpful functions and macros for ROS Nodes, the ROS molecular unit of worker.
  """

  @doc false
  def start_link(_opts) do
    {:ok, ips} = :inet.getif()

    local_ip =
      ips
      |> Enum.map(fn {ip, _broadaddr, _mask} -> ip end)
      |> Enum.reject(fn ip -> ip == {127, 0, 0, 1} end)
      |> Enum.map(&Tuple.to_list/1)
      |> Enum.map(&Enum.join(&1, "."))
      |> List.first()

    Agent.start_link(fn -> %{ip: local_ip} end, name: __MODULE__)
  end

  def get_ip, do: Agent.get(__MODULE__, fn %{ip: ip} -> ip end)
end
