defmodule SpaceBirds.BuffDebuff.Ignite do
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.State.Arena
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    damage: number,
    damage_done: number,
    curve: ProgressOverTime.curve,
    ticks: number,
    current_tick: number
  }

  @impl(BuffDebuff)
  def on_apply(slow, buff_debuff_stack, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, buff_debuff_stack.actor),
         false <- MapSet.member?(readonly_stats.status, :immune)
    do
      apply_default(slow, buff_debuff_stack, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  @impl(BuffDebuff)
  def run(ignite, component, arena) do
    {:ok, arena} = evaluate_expiration(ignite, component, arena)

    progress = 1 - (ignite.time_remaining / ignite.time)
    next_tick = floor(ProgressOverTime.linear(%{from: 0, to: ignite.debuff_data.ticks}, progress))

    with current_tick when next_tick > current_tick <- ignite.debuff_data.current_tick,
         {:ok, stats} <- Components.fetch(arena.components, :stats, component.actor)
    do
      tick = current_tick + 1
      damage = apply(
        ProgressOverTime,
        String.to_existing_atom(ignite.debuff_data.curve),
        [%{from: 0, to: ignite.debuff_data.damage}, tick / ignite.debuff_data.ticks]
      ) - ignite.debuff_data.damage_done

      ignite = update_in(ignite.debuff_data.damage_done, &(&1 + damage))
      ignite = put_in(ignite.debuff_data.current_tick, tick)

      {:ok, stats} = Stats.receive_damage(stats, damage, arena)

      {:ok, arena} = Arena.update_component(arena, stats, fn _ -> {:ok, stats} end)
      update_in_stack(ignite, component, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

end
