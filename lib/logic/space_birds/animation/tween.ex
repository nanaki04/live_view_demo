defmodule SpaceBirds.Animations.Tween do
  alias SpaceBirds.Logic.ProgressOverTime

  @spec calculate_value(last :: Frame.t, next :: Frame.t, last_value :: number, next_value :: number, animation_time :: number) :: number
  def calculate_value(last, next, last_value, next_value, animation_time) do
    progress = (animation_time - last.time) / (next.time - last.time)
    case last.tween_type do
      "sine_curve" ->
        ProgressOverTime.sine_curve(%{from: last_value, to: next_value}, progress)
      "inverse_sine_curve" ->
        ProgressOverTime.inverse_sine_curve(%{from: last_value, to: next_value}, progress)
      _ ->
        ProgressOverTime.linear(%{from: last_value, to: next_value}, progress)
    end
  end

end
