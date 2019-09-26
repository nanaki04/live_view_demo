defmodule SpaceBirds.BuffDebuff.Slow do
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.Components.Stats
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    acceleration_decrease: ProgressOverTime.t,
    top_speed_decrease: ProgressOverTime.t,
    drag_increase: ProgressOverTime.t
  }

  @impl(BuffDebuff)
  def on_apply(slow, buff_debuff_stack, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, buff_debuff_stack.actor),
         false <- MapSet.member?(readonly_stats.status, :slow_resistant),
         false <- MapSet.member?(readonly_stats.status, :immune),
         false <- MapSet.member?(readonly_stats.status, {:immune_to, "slow"})
    do
      apply_default(slow, buff_debuff_stack, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  @impl(BuffDebuff)
  def affect_stats(slow, stats, _arena) do
    progress = (slow.time - slow.time_remaining) / slow.time
    acceleration_decrease = ProgressOverTime.inverse_sine_curve(slow.debuff_data.acceleration_decrease, progress)
    top_speed_decrease = ProgressOverTime.inverse_sine_curve(slow.debuff_data.top_speed_decrease, progress)
    drag_increase = ProgressOverTime.inverse_sine_curve(slow.debuff_data.drag_increase, progress)

    stats = update_in(stats.component_data.acceleration, & max(0, &1 - acceleration_decrease))
    stats = update_in(stats.component_data.top_speed, & max(0, &1 - top_speed_decrease))
    stats = update_in(stats.component_data.drag, & max(0, &1 + drag_increase))

    {:ok, stats}
  end

  @impl(BuffDebuff)
  def apply_diminishing_returns(slow, level) do
    slow
    |> update_in([:debuff_data, :acceleration_decrease, :from], & &1 / (level + 1))
    |> update_in([:debuff_data, :top_speed_decrease, :from], & &1 / (level + 1))
    |> update_in([:debuff_data, :drag_increase, :from], & &1 / (level + 1))
    |> ResultEx.return
  end

end
