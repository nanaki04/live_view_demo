defmodule SpaceBirds.State.PreloadSupervisor do
  use DynamicSupervisor

  @vsn "0"

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child({:via, Registry, {SpaceBirds.State.PreloadRegistry, _}} = id, player_pid) do
    spawn_preloader(id, player_pid)
  end

  def start_child(id, player_pid) do
    id
    |> via
    |> spawn_preloader(player_pid)
  end

  @impl(DynamicSupervisor)
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec via(String.t) :: GenServer.name
  def via(id) do
    {:via, Registry, {SpaceBirds.State.PreloadRegistry, id}}
  end

  defp spawn_preloader(id, player_pid) do
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {SpaceBirds.State.Preloader, id: id, player_pid: player_pid})
    {:ok, id}
  end

end
