defmodule SpaceBirds.Weapons.Rebirth do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "shockwave"

  @type t :: %{
    enhancements: [term],
    path: String.t
  }

  defstruct enhancements: [],
    path: "default"

  def fire(weapon, _target_position, arena) do
    path = case weapon.weapon_data.path do
      "default" -> @default_path
      path -> path
    end

    effect_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, effect} <- MasterData.get_projectile(path, effect_id, weapon.actor),
         {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor),
         {:ok, rebirth} <- MasterData.get_buff_debuff("rebirth", weapon.actor)
    do
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, rebirth, arena)

      effect = put_in(effect.transform.component_data.position, transform.component_data.position)

      Arena.add_actor(arena, effect)
      |> ResultEx.bind(& Arena.update_component(&1, transform, fn _ -> {:ok, transform} end))
    else
      _ ->
        {:ok, arena}
    end
  end

end
