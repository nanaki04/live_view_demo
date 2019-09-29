defmodule SpaceBirds.State.ArenaRegistry do

  def list_all() do
    Registry.select(SpaceBirds.State.ArenaRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def list_all_joinable() do
    battle_ids = GenServer.call(SpaceBirds.State.Players, :find_online)
                 |> ResultEx.unwrap!
                 |> Enum.map(fn %{battle_id: battle_id} -> battle_id end)

    list_all()
    |> Enum.map(fn battle_id -> {:via, Registry, {SpaceBirds.State.ArenaRegistry, battle_id}} end)
    |> Enum.filter(fn battle -> GenServer.whereis(battle) != nil end)
    |> Enum.filter(fn battle -> Enum.count(battle_ids, &(&1 == battle)) < 4 end)
    |> Enum.map(fn {_via, _reg, {_mod, battle_id}} -> battle_id end)
  end

end
