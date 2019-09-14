defmodule SpaceBirds.State.BackPressureSupervisor do
  alias SpaceBirds.State.BackPressureSystem
  use DynamicSupervisor

  @vsn "0"

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child({:via, Registry, {SpaceBirds.State.BackPressureRegistry, _}} = id) do
    create_back_pressure_system(id)
  end

  def start_child(player_id, {_, _, {_, battle_id}}) do
    start_child(player_id, battle_id)
  end

  def start_child(player_id, battle_id) do
    via(player_id, battle_id)
    |> create_back_pressure_system
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def via(player_id, {_, _, {_, battle_id}}) do
    via(player_id, battle_id)
  end

  def via(player_id, battle_id) do
    {:via, Registry, {SpaceBirds.State.BackPressureRegistry, "#{player_id}_#{battle_id}"}}
  end

  defp create_back_pressure_system(id) do
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {BackPressureSystem, id: id})
    {:ok, id}
  end

end
