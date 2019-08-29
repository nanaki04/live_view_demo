defmodule SpaceBirds.BuffDebuff.SlowImmune do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.BuffDebuffStack
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{}

  @impl(BuffDebuff)
  def on_apply(slow_immune, buff_debuff_stack, arena) do
    {:ok, arena} = put_in(slow_immune.time_remaining, slow_immune.time)
                   |> add_to_stack(buff_debuff_stack, arena)

    Arena.update_component(arena, buff_debuff_stack, fn buff_debuff_stack ->
      BuffDebuffStack.remove_by_type(buff_debuff_stack, "slow")
    end)
  end

  @impl(BuffDebuff)
  def affect_stats(_, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, :slow_immune))
    |> ResultEx.return
  end

end
