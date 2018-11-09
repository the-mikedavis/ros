defmodule MyRosProject.AddTwoIntsServer do
  use GenServer
  require Logger

  alias RospyTutorials.AddTwoInts.{Request, Response}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts), do: {:ok, opts}

  def handle_call({:service, %Request{a: a, b: b}}, _from, state) do
    Logger.info(fn -> "[#{a} + #{b} = #{a + b}]" end)

    {:reply, %Response{sum: a + b}, state}
  end
end
