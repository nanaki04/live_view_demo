defmodule SpaceBirds.BuffDebuff.Channel do
  alias SpaceBirds.Components.Stats
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    weapon: Weapon.weapon_slot
  }

  @callback run(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @impl(BuffDebuff)
  def run(channel, component, arena) do
    # get movement actions
  end

  @impl(BuffDebuff)
  def affect_stats(channel, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, {:channeling, channel.debuff_data.weapon}))
    |> ResultEx.return
  end

end
