defmodule SpaceBirds.Weapons.Discharge do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "none"

  @type t :: %{
    path: String.t,
    enhancements: [term]
  }

  defstruct path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(weapon, _target_position, arena) do
    path = case weapon.weapon_data.path do
      "default" -> @default_path
      path -> path
    end

    {:ok, arena} = add_buffs(weapon, arena)
    spawn_projectile(weapon, path, arena)
  end

  defp add_buffs(weapon, arena) do
    with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor),
         {:ok, haste} <- MasterData.get_buff_debuff("haste"),
         {:ok, immune_to_slow} <- MasterData.get_buff_debuff("immune_to_slow"),
         {:ok, immune_to_stun} <- MasterData.get_buff_debuff("immune_to_stun")
    do
      {:ok, arena} = BuffDebuffStack.remove_by_type(buff_debuff_stack, "stun", arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.remove_by_type(buff_debuff_stack, "slow", arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, haste, arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, immune_to_slow, arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      BuffDebuffStack.apply(buff_debuff_stack, immune_to_stun, arena)
    else
      _ ->
        {:ok, arena}
    end

  end

  defp spawn_projectile(_weapon, "none", arena) do
    {:ok, arena}
  end

  defp spawn_projectile(weapon, path, arena) do
    effect_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, effect} <- MasterData.get_projectile(path, effect_id, weapon.actor)
    do
      effect = put_in(effect.transform.component_data.position, transform.component_data.position)

      Arena.add_actor(arena, effect)
      |> ResultEx.bind(& Arena.update_component(&1, transform, fn _ -> {:ok, transform} end))
    else
      _ ->
        {:ok, arena}
    end
  end

end
