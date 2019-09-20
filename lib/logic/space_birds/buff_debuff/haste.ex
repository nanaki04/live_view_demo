defmodule SpaceBirds.BuffDebuff.Haste do
  alias SpaceBirds.Logic.ProgressOverTime
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    acceleration_increase: ProgressOverTime.t,
    top_speed_increase: ProgressOverTime.t,
    drag_decrease: ProgressOverTime.t
  }

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
