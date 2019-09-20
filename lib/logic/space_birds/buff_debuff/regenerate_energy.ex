defmodule SpaceBirds.BuffDebuff.RegenerateEnergy do
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    regeneration_increase: number,
  }

  @impl(BuffDebuff)
  def affect_stats(buff, stats, _arena) do
    stats = update_in(stats.component_data.energy_regeneration, & max(0, &1 + buff.buff_data.regeneration_increase))

    {:ok, stats}
  end

end
