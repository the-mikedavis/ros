defmodule ROS.SlaveApi.Behaviour do
  @moduledoc """
  The ROS Slave API interface.

  These functions are called by the ROS master node via XML-RPC.
  """

  @type caller_id :: String.t()

  @callback get_bus_stats(caller_id()) :: {integer(), String.t(), [any()]}
  @callback get_bus_info(caller_id()) :: {integer(), String.t(), [any()]}
  @callback get_master_uri(caller_id()) :: {integer(), String.t(), String.t()}
  @callback shutdown(caller_id()) :: {integer(), String.t(), integer()}
  @callback shutdown(caller_id(), message :: String.t()) :: {integer(), String.t(), integer()}
  @callback get_pid(caller_id()) :: {integer(), String.t(), integer()}
  @callback get_subscriptions(caller_id()) :: {integer(), String.t(), [[String.t()]]}
  @callback get_publications(caller_id()) :: {integer(), String.t(), [[String.t()]]}
  @callback param_update(caller_id(), parameter_key :: String.t(), parameter_value :: any()) :: {integer(), String.t(), integer()}
  @callback publisher_update(caller_id(), topic :: String.t(), publishers :: [String.t()]) :: {integer(), String.t(), integer()}
  @callback request_topic(caller_id(), topic :: String.t(), protocol :: [[String.t()]]) :: {integer(), String.t(), [any()]}
end
