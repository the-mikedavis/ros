defmodule ROS.Service.Proxy do
  use GenServer
  use Private
  require Logger

  alias ROS.Message.ConnectionHeader, as: ConnHead

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
  @spec request(atom(), struct()) :: {:ok, struct()} | {:error, String.t()}
  def request(proxy, data, timeout \\ 5000),
    do: GenServer.call(proxy, {:request, data}, timeout)

  @doc """
  Makes a request to a service.

  If the request is not successful, a `ROS.Service.Error` is raised.

  ## Examples

      iex> alias ROS.Service.Proxy, as: SrvPrx
      iex> SrvPrx.request!(:myproxy, %RospyTutorials.AddTwoInts.Request{a: 3, b: 4))
      %RospyTutorials.AddTwoInts.Response{sum: 7}
      iex> SrvPrx.request!(:ididntmakethisserviceproxy, %ThisDoesntExist{})
      (** ROS.Service.Error) ...
  """
  @spec request!(atom(), struct()) :: struct() | no_return()
  def request!(proxy, data, timeout \\ 5000) do
    case request(proxy, data, timeout) do
      {:ok, response} -> response

      {:error, reason} -> raise ROS.Service.Error, message: reason
    end
  end

  ## Server API
  @doc false
  @spec from_node_name(atom(), Keyword.t()) :: atom()
  def from_node_name(node_name, opts) do
    String.to_atom(Atom.to_string(node_name) <> "_" <> opts[:service])
  end

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
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
           {:ok, conn_head} <- get_conn_header(socket),
           request <- ROS.Message.serialize(data),
           :ok <- send_line(socket, request),
           {:ok, raw_response} <- read_line(socket) do
        ROS.Service.deserialize_response(raw_response, proxy[:type])
      else
        e -> e
      end

    {:reply, response, proxy}
  end

  private do
    @spec lookup_service(Keyword.t()) :: {:ok, String.t()} | {:error, :noservices}
    defp lookup_service(proxy) do
      case ROS.MasterApi.lookup_service(proxy) do
        [1, _, uri] ->
          {:ok, uri}

        _ -> {:error, :noservices}
      end
    end

    @spec connect(String.t()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
    defp connect("rosrpc://" <> uri) do
      [host, port_string] = String.split(uri, ":")
      port = String.to_integer(port_string)
      # connect to the host blocking-ly
      host
      |> String.to_charlist()
      |> :gen_tcp.connect(port, [:binary, packet: 0, reuseaddr: true, active: false])
    end

    @spec accept(:gen_tcp.socket()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
    defp accept(socket) do
      :gen_tcp.accept(socket)
    end

    @spec read_line(:gen_tcp.socket()) :: {:ok, binary()} | {:error, atom()}
    defp read_line(socket) do
      :gen_tcp.recv(socket, 0)
    end

    @spec get_conn_header(:gen_tcp.socket()) :: {:ok, %ConnHead{}} | {:error, atom()}
    defp get_conn_header(socket) do
      case read_line(socket) do
        {:ok, recv} -> {:ok, ConnHead.parse(recv)}
        e -> e
      end
    end

    @spec send_line(:gen_tcp.socket(), binary()) :: :ok | {:error, atom()}
    defp send_line(socket, line) do
      :gen_tcp.send(socket, line)
    end

    @spec send_conn_header(:gen_tcp.socket(), Keyword.t()) :: :ok | {:error, atom()}
    defp send_conn_header(socket, proxy) do
      message =
        proxy
        |> ConnHead.from()
        |> ConnHead.serialize()

      send_line(socket, message)
    end
  end
end
