defmodule SpaceBirds.BuffDebuff.Stun do
  alias SpaceBirds.Components.Stats
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{}

  @impl(BuffDebuff)
  def on_apply(stun, buff_debuff_stack, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, buff_debuff_stack.actor),
         false <- MapSet.member?(readonly_stats.status, :stun_resistant),
         false <- MapSet.member?(readonly_stats.status, :immune)
    do
      put_in(stun.time_remaining, stun.time)
      |> add_to_stack(buff_debuff_stack, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  @impl(BuffDebuff)
  def affect_stats(_, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, :stunned))
    |> ResultEx.return
  end

end
