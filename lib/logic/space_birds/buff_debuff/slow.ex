defmodule SpaceBirds.BuffDebuff.Slow do
  alias SpaceBirds.Logic.ProgressOverTime
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    acceleration_decrease: ProgressOverTime.t,
    top_speed_decrease: ProgressOverTime.t,
    drag_increase: ProgressOverTime.t
  }

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

end
