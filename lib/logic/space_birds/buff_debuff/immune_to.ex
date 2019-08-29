defmodule SpaceBirds.BuffDebuff.ImmuneTo do
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    to: Actor.t
  }

  @impl(BuffDebuff)
  def affect_stats(immune_to, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, {:immune_to, immune_to.buff_data.to}))
    |> ResultEx.return
  end

end
