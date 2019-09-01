defmodule SpaceBirds.BuffDebuff.ImmuneTo do
  alias SpaceBirds.Components.Actor
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    to: Actor.t | String.t
  }

  @spec new(Actor.t | String.t, cooldown :: number) :: BuffDebuff.t
  def new(tag, cooldown) do
    %BuffDebuff{
      type: "immune_to",
      time: cooldown,
      time_remaining: cooldown,
      buff_data: %{
        to: tag
      }
    }
  end

  @impl(BuffDebuff)
  def affect_stats(buff_debuff, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, {:immune_to, buff_debuff.buff_data.to}))
    |> ResultEx.return
  end

end
