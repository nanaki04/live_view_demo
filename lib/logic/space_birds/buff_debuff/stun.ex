defmodule SpaceBirds.BuffDebuff.Stun do
  alias SpaceBirds.Logic.ProgressOverTime
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{}

  @impl(BuffDebuff)
  def affect_stats(slow, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, :stunned))
    |> ResultEx.return
  end

end
