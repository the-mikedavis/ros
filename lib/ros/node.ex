defmodule ROS.Node do
  use Supervisor

  @hidden_processes [
    # the XMLRPC server
    {ROSWeb.Endpoint, port: 0},
    # the local paremeter & state server
    {ROS.LocalParameterServer, %{}}
  ]

  def start_link(children, opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(__MODULE__, children ++ @hidden_processes, name: name)
  end

  @impl Supervisor
  def init(children) do
    Supervisor.init(children, strategy: :one_for_one)
  end

  ## ------------------------------------ ##

  use Agent

  @doc false
  def start_link_2(_opts) do
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

  def get_uri, do: Agent.get(__MODULE__, fn %{uri: ip} -> ip end)
end
