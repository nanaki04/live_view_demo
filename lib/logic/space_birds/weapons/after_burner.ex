defmodule SpaceBirds.Weapons.AfterBurner do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "shockwave"

  @type t :: %{
    projectile_path: String.t,
    enhancements: [term]
  }

  defstruct projectile_path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(weapon, _target_position, arena) do
    path = case weapon.weapon_data.projectile_path do
      "default" -> @default_path
      path -> path
    end

    effect_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, effect} <- MasterData.get_projectile(path, effect_id, weapon.actor),
         {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor),
         {:ok, haste} <- MasterData.get_buff_debuff("after_burner"),
         {:ok, immune_to_slow} <- MasterData.get_buff_debuff("immune_to_slow")
    do
      {:ok, arena} = BuffDebuffStack.remove_by_type(buff_debuff_stack, "slow", arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, haste, arena)
      {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, immune_to_slow, arena)

      effect = put_in(effect.transform.component_data.position, transform.component_data.position)

      Arena.add_actor(arena, effect)
      |> ResultEx.bind(& Arena.update_component(&1, transform, fn _ -> {:ok, transform} end))
    else
      _ ->
        {:ok, arena}
    end
  end

end
