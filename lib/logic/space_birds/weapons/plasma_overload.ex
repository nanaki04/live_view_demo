defmodule SpaceBirds.Weapons.PlasmaOverload do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.Arsenal
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.BuffDebuff.Channel
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "plasma_overload"
  @default_channel_effect_path "plasma_overload_channel"

  @type t :: %{
    channel_time: number,
    channel_time_remaining: number,
    charges: number,
    enhancements: [term],
    channel_effect_path: String.t,
    path: String.t,
    channeling: boolean,
    projectile_count: number
  }

  defstruct channel_time: 1000,
    channel_time_remaining: 1000,
    charges: 5,
    enhancements: [],
    channel_effect_path: "default",
    path: "default",
    channeling: false,
    projectile_count: 0

  @impl(Weapon)
  def fire(weapon, _, arena) do
    {:ok, arena} = with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
    do
      path = if weapon.weapon_data.channel_effect_path == "default" do
        @default_channel_effect_path
      else
        weapon.weapon_data.channel_effect_path
      end

      channel = Channel.new(weapon.weapon_slot, path)
      BuffDebuffStack.apply(buff_debuff_stack, channel, arena)
    else
      _ ->
        {:ok, arena}
    end

    Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
      weapon = put_in(weapon.weapon_data.channeling, true)
      weapon = put_in(weapon.weapon_data.channel_time_remaining, weapon.weapon_data.channel_time)
      Arsenal.put_weapon(arsenal, weapon)
    end)
  end

  def run(%{weapon_data: %{channeling: true}} = weapon, arena) do
    with true <- weapon.weapon_data.channeling,
         {:ok, stats} <- Stats.get_readonly(arena, weapon.actor),
         false <- MapSet.member?(stats.component_data.status, :stunned),
         true <- MapSet.member?(stats.component_data.status, {:channeling, weapon.weapon_slot})
    do
      channel_time = weapon.weapon_data.channel_time
      time_remaining = weapon.weapon_data.channel_time_remaining
      progress = (channel_time - time_remaining) / channel_time

      next_hit_count = ProgressOverTime.linear(%{from: 0, to: weapon.weapon_data.charges}, progress)
                       |> round

      weapon = update_in(weapon.weapon_data.channel_time_remaining, &(max(0, &1 - arena.delta_time * 1000)))
      {:ok, arena} = Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
        Arsenal.put_weapon(arsenal, weapon)
      end)

      {:ok, arena} = remove_channel(weapon, arena)

      if next_hit_count > weapon.weapon_data.projectile_count && next_hit_count <= weapon.weapon_data.charges do
        weapon = update_in(weapon.weapon_data.projectile_count, &(&1 + 1))

        {:ok, arena} = Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
          Arsenal.put_weapon(arsenal, weapon)
        end)

        spawn_projectile(weapon, arena)
      else
        {:ok, arena}
      end
    else
      _ ->
        Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
          weapon = put_in(weapon.weapon_data.projectile_count, 0)
          weapon = put_in(weapon.weapon_data.channeling, false)
          Arsenal.put_weapon(arsenal, weapon)
        end)
    end
  end

  def run(weapon, arena) do
    cool_down(weapon, arena)
  end

  defp spawn_projectile(weapon, arena) do
    path = if weapon.weapon_data.path == "default", do: @default_path, else: weapon.weapon_data.path
    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile} <- MasterData.get_projectile(path, projectile_id, weapon.actor)
    do
      rotation = case rem(weapon.weapon_data.projectile_count, 10) do
        0 -> 135
        1 -> 225
        2 -> 45
        3 -> 315
        4 -> 175
        5 -> 290
        6 -> 215
        7 -> 15
        8 -> 145
        9 -> 350
      end

      projectile = put_in(projectile.transform.component_data.rotation, rotation)
      projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)

      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

  defp remove_channel(%{weapon_data: %{channel_time_remaining: time_remaining}} = weapon, arena) when time_remaining <= 0 do
    with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
    do
      BuffDebuffStack.remove_by_type(buff_debuff_stack, "channel", arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  defp remove_channel(_, arena), do: {:ok, arena}

end
