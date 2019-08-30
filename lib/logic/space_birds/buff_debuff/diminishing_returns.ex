defmodule SpaceBirds.BuffDebuff.DiminishingReturns do
  alias SpaceBirds.MasterData
  alias SpaceBirds.Components.Stats
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    for: MasterData.buff_debuff_type
  }

  @spec new(MasterData.buff_debuff_type, cooldown :: number) :: BuffDebuff.t
  def new(debuff_type, cooldown) do
    %BuffDebuff{
      type: "diminishing_returns",
      time_remaining: cooldown,
      buff_data: %{
        for: debuff_type
      }
    }
  end

  @impl(BuffDebuff)
  def affect_stats(buff_debuff, stats, _arena) do
    Stats.update_diminishing_returns_level(stats, buff_debuff.buff_data.for, & &1 + 1)
  end

end
