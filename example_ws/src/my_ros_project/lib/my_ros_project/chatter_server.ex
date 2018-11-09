defmodule MyRosProject.ChatterServer do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(args), do: {:ok, args}

  def handle_cast({:subscription, _from, data}, state) do
    IO.inspect(data, label: "Incomming msg in the ChatterServer")

    {:noreply, state}
  end
end
