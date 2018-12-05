defmodule MyRosProject.ChatterServer do
  use GenServer
  require Logger

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(args), do: {:ok, args}

  def handle_cast({:subscription, _from, data}, state) do
    Logger.info(fn -> "I heard #{inspect(data)}" end)

    {:noreply, state}
  end
end
