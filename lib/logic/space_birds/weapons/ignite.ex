defmodule SpaceBirds.Weapons.Ignite do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "ignite"
  @offset %{x: 0, y: -80}

  @type t :: %{
    enhancements: [term],
    path: String.t
  }

  defstruct enhancements: [],
    path: "default"

  @impl(Weapon)
  def fire(weapon, _target_position, arena) do
    path = case weapon.weapon_data.path do
      "default" -> @default_path
      "" -> @default_path
      path -> path
    end
    effect_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, effect} <- MasterData.get_projectile(path, effect_id, weapon.actor)
    do
      position = Transform.offset(transform, @offset)
      rotation = transform.component_data.rotation
      effect = put_in(effect.transform.component_data.position, position)
      effect = put_in(effect.transform.component_data.rotation, rotation)

      Arena.add_actor(arena, effect)
    else
      _ ->
        {:ok, arena}
    end
  end

end
