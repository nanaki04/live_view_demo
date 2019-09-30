defmodule SpaceBirds.State.ArenaBackupSupervisor do
  use DynamicSupervisor

  @vsn "0"

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child(%{id: {:via, Registry, {SpaceBirds.State.ArenaRegistry, id}}} = arena) do
    via(id)
    |> create_arena_backup(arena)
  end

  def find({:via, Registry, {SpaceBirds.State.ArenaRegistry, id}}) do
    backup_id = via(id)
    if is_pid(GenServer.whereis(backup_id)) do
      {:some, GenServer.call(backup_id, :retrieve)}
    else
      :none
    end
  end

  @impl(DynamicSupervisor)
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp via(id) do
    {:via, Registry, {SpaceBirds.State.ArenaBackupRegistry, id}}
  end

  defp create_arena_backup(id, arena) do
    DynamicSupervisor.start_child(__MODULE__, {SpaceBirds.State.ArenaBackup, id: id, arena: arena})
  end

end
