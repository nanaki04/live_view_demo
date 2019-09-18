defmodule SpaceBirds.BuffDebuff.Haste do
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.Components.Stats
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    acceleration_increase: ProgressOverTime.t,
    top_speed_increase: ProgressOverTime.t,
    drag_decrease: ProgressOverTime.t
  }

  @impl(BuffDebuff)
  def on_apply(haste, buff_debuff_stack, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, buff_debuff_stack.actor),
         false <- MapSet.member?(readonly_stats.status, :haste_resistant),
         false <- MapSet.member?(readonly_stats.status, :immune)
    do
      apply_default(haste, buff_debuff_stack, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  @impl(BuffDebuff)
  def affect_stats(haste, stats, _arena) do
    progress = (haste.time - haste.time_remaining) / haste.time
    acceleration_increase = ProgressOverTime.inverse_sine_curve(haste.buff_data.acceleration_increase, progress)
    top_speed_increase = ProgressOverTime.inverse_sine_curve(haste.buff_data.top_speed_increase, progress)
    drag_decrease = ProgressOverTime.inverse_sine_curve(haste.buff_data.drag_decrease, progress)

    stats = update_in(stats.component_data.acceleration, & max(0, &1 + acceleration_increase))
    stats = update_in(stats.component_data.top_speed, & max(0, &1 + top_speed_increase))
    stats = update_in(stats.component_data.drag, & max(0, &1 - drag_decrease))

    {:ok, stats}
  end

  @impl(BuffDebuff)
  def apply_diminishing_returns(haste, level) do
    haste
    |> update_in([:buff_data, :acceleration_increase, :from], & &1 / (level + 1))
    |> update_in([:buff_data, :top_speed_increase, :from], & &1 / (level + 1))
    |> update_in([:buff_data, :drag_decrease, :from], & &1 / (level + 1))
  end

end
