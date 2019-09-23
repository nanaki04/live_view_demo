defmodule SpaceBirds.BuffDebuff.Channel do
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Actions.Actions
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    weapon: Weapon.weapon_slot
  }

  defstruct weapon: 0

  @spec new(Weapon.weapon_slot, effect_type :: String.t, time :: number) :: BuffDebuff.t
  def new(weapon_slot, effect_type, owner, time \\ 10000) do
    %BuffDebuff{
      owner: owner,
      type: "channel",
      time: time,
      time_remaining: time,
      effect_type: effect_type,
      debuff_data: %__MODULE__{
        weapon: weapon_slot
      }
    }
  end

  @impl(BuffDebuff)
  def run(channel, component, arena) do
    remove_on_stun(channel, component, arena)
    |> OptionEx.or_try(fn -> remove_on_cancel(channel, component, arena) end)
    |> OptionEx.or_else_with(fn -> evaluate_expiration(channel, component, arena) end)
  end

  @impl(BuffDebuff)
  def affect_stats(channel, stats, _arena) do
    update_in(stats.component_data.status, & MapSet.put(&1, {:channeling, channel.debuff_data.weapon}))
    |> ResultEx.return
  end

  defp remove_on_stun(channel, component, arena) do
    with {:ok, stats} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(stats.component_data.status, :stunned)
    do
      :none
    else
      true ->
        {:some, on_remove(channel, component, arena)}
      _ ->
        :none
    end
  end

  defp remove_on_cancel(channel, component, arena) do
    with {:ok, player_id} <- Arena.find_player_by_actor(arena, component.actor),
         [_ | _] = actions <- Actions.filter_by_player_id(arena.actions, player_id),
         [_ | _] <- Actions.filter_by_action_name(actions, :cancel)
    do
      {:some, on_remove(channel, component, arena)}
    else
      _ ->
        :none
    end
  end

end
