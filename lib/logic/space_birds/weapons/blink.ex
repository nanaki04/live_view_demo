defmodule SpaceBirds.Weapons.Blink do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Arsenal
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.MasterData
  use Weapon

  @default_origin_effect_path "blink_origin"
  @default_destination_effect_path "blink_destination"

  @type t :: %{
    origin_effect_path: String.t,
    destination_effect_path: String.t,
    enhancements: [term],
    extra_charge_window: number,
    extra_charge_timer: number
  }

  defstruct origin_effect_path: "default",
    destination_effect_path: "default",
    enhancements: [],
    extra_charge_window: 3000,
    extra_charge_timer: 0

  @impl(Weapon)
  def fire(weapon, target_position, arena) do
    weapon = if weapon.weapon_data.extra_charge_timer > 0 do
               put_in(weapon.weapon_data.extra_charge_timer, 0)
             else
               put_in(weapon.weapon_data.extra_charge_timer, weapon.weapon_data.extra_charge_window)
             end

    {:ok, arena} = Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
      Arsenal.put_weapon(arsenal, weapon)
    end)

    origin_path = case weapon.weapon_data.origin_effect_path do
      "default" -> @default_origin_effect_path
      path -> path
    end

    destination_path = case weapon.weapon_data.destination_effect_path do
      "default" -> @default_destination_effect_path
      path -> path
    end

    origin_effect_id = arena.last_actor_id + 1
    destination_effect_id = arena.last_actor_id + 2

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, origin_effect} <- MasterData.get_projectile(origin_path, origin_effect_id, weapon.actor),
         {:ok, destination_effect} <- MasterData.get_projectile(destination_path, destination_effect_id, weapon.actor),
         {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor),
         {:ok, haste} <- MasterData.get_buff_debuff("haste"),
         {:ok, immune_to_slow} <- MasterData.get_buff_debuff("immune_to_slow")
    do
      {:ok, arena} = BuffDebuffStack.remove_by_type(buff_debuff_stack, "slow", arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, haste, arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, immune_to_slow, arena)

      origin_effect = put_in(origin_effect.transform.component_data.position, transform.component_data.position)
      destination_effect = put_in(destination_effect.transform.component_data.position, target_position)
      transform = put_in(transform.component_data.position, target_position)

      Arena.add_actor(arena, origin_effect)
      |> ResultEx.bind(& Arena.add_actor(&1, destination_effect))
      |> ResultEx.bind(& Arena.update_component(&1, transform, fn _ -> {:ok, transform} end))
    else
      _ ->
        {:ok, arena}
    end
  end

  def run(%{weapon_data: %{extra_charge_timer: timer}} = weapon, arena) when timer > 0 do
    weapon = put_in(weapon.cooldown_remaining, 0)
    weapon = update_in(weapon.weapon_data.extra_charge_timer, &(max(0, &1 - arena.delta_time * 1000)))
    weapon = if weapon.weapon_data.extra_charge_timer == 0 do
               put_in(weapon.cooldown_remaining, weapon.cooldown)
             else
               weapon
             end

    Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
      Arsenal.put_weapon(arsenal, weapon)
    end)
  end

  def run(weapon, arena) do
    {:ok, {_weapon, arena}} = cool_down(weapon, arena)
    {:ok, arena}
  end

end
