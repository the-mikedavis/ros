defmodule ROS.Service.Proxy do
  use GenServer
  use Private
  require Logger

  alias ROS.Message.ConnectionHeader, as: ConnHead
  alias ROS.{Helpers, TCP}

  @moduledoc """
  Service Proxies allow you to make requests to services.

  All requests to services are blocking. Such is the nature of ROS Service
  calls. If you have a service running, you can use a service proxy like so:

      iex> import ROS.Node.Spec
      iex> alias ROS.Service.Proxy, as: SrvPrx
      iex> children = [
      ...>   node(:mynode, [
      ...>     service_proxy(:myproxy, "/add_two_ints", "rospy_tutorials/AddTwoInts")
      ...>   ]
      ...> ]
      iex> Supervisor.start_link(children, strategy: :one_for_one)
      iex> SrvPrx.request(:myproxy, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4))
      {:ok, %RospyTutorials.AddTwoInts.Response{sum: 7}}
  """

  ## Client API

  @doc """
  Makes a request to a service.

  Returns a tuple `{:ok, %ServiceType.Response{}}` if the service call is
  successful and a `{:error, "reason"}` tuple if the service call fails.

  ## Examples

      iex> alias ROS.Service.Proxy, as: SrvPrx
      iex> SrvPrx.request(:myproxy, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4))
      {:ok, %RospyTutorials.AddTwoInts.Response{sum: 7}}
  """
  @spec request(atom(), struct() | map(), non_neg_integer()) ::
          {:ok, struct()} | {:error, String.t()}
  def request(proxy, data, timeout \\ 5000),
    do: GenServer.call(proxy, {:request, data}, timeout)

  @doc """
  Makes a request to a service.

  If the request is not successful, a `ROS.Service.Error` is raised.

  ## Examples

      iex> alias ROS.Service.Proxy, as: SrvPrx
      iex> SrvPrx.request!(:myproxy, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4))
      %RospyTutorials.AddTwoInts.Response{sum: 7}
      iex> SrvPrx.request!(:ididntmakethisserviceproxy, %StdSrv.Empty{})
      (** ROS.Service.Error) ...
  """
  @spec request!(atom(), struct() | map(), non_neg_integer()) ::
          struct() | no_return()
  def request!(proxy, data, timeout \\ 5000) do
    case request(proxy, data, timeout) do
      {:ok, response} -> response
      {:error, reason} -> raise ROS.Service.Error, message: reason
    end
  end

  ## Server API

  @enforce_keys [:name, :service, :type]
  defstruct @enforce_keys ++ [:node_name, :uri]

  @doc false
  def start_link(srv_prx) do
    GenServer.start_link(__MODULE__, srv_prx, name: srv_prx.name)
  end

  @impl GenServer
  @doc false
  def init(opts), do: {:ok, opts}

  @impl GenServer
  @doc false
  def handle_call({:request, data}, _from, proxy) do
    # if any of the with calls don't match, it falls through to the else
    response =
      with {:ok, uri} <- lookup_service(proxy),
           {:ok, socket} <- connect(uri),
           :ok <- send_conn_header(socket, proxy),
           {:ok, _conn_head} <- get_conn_header(socket),
           request_module <-
             proxy.type |> Helpers.module() |> Module.concat(Request),
           typed_data <- Helpers.force_type(data, request_module),
           request <- ROS.Message.serialize(typed_data),
           :ok <- TCP.send(request, socket),
           {:ok, raw_response} <- read_line(socket) do
        ROS.Service.deserialize_response(raw_response, proxy.type)
      else
        e -> e
      end

    {:reply, response, proxy}
  end

  private do
    @spec lookup_service(%ROS.Service.Proxy{}) ::
            {:ok, String.t()} | {:error, :noservices}
    defp lookup_service(proxy) do
      case ROS.MasterApi.lookup_service(proxy) do
        [1, _, uri] ->
          {:ok, uri}

        _ ->
          {:error, :noservices}
      end
    end

    @spec connect(String.t()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
    defp connect("rosrpc://" <> uri) do
      [host, port_string] = String.split(uri, ":")
      port = String.to_integer(port_string)
      # connect to the host blocking-ly
      host
      |> String.to_charlist()
      |> :gen_tcp.connect(port, [
        :binary,
        packet: 0,
        reuseaddr: true,
        active: false
      ])
    end

    @spec read_line(:gen_tcp.socket()) :: {:ok, binary()} | {:error, atom()}
    defp read_line(socket) do
      :gen_tcp.recv(socket, 0)
    end

    @spec get_conn_header(:gen_tcp.socket()) ::
            {:ok, %ConnHead{}} | {:error, atom()}
    defp get_conn_header(socket) do
      case read_line(socket) do
        {:ok, recv} -> {:ok, ConnHead.parse(recv)}
        e -> e
      end
    end

    @spec send_conn_header(:gen_tcp.socket(), %ROS.Service.Proxy{}) ::
            :ok | {:error, atom()}
    defp send_conn_header(socket, proxy) do
      proxy
      |> ConnHead.from()
      |> ConnHead.serialize()
      |> TCP.send(socket)
    end
  end
end
