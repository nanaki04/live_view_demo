defmodule SpaceBirds.Weapons.PlasmaBurst do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_projectile_path "plasma_burst"
  @offset %{x: 0, y: -30}

  @type t :: %{
    projectile_path: String.t,
    enhancements: [term]
  }

  defstruct projectile_path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(weapon, target_position, arena) do
    path = case weapon.weapon_data.projectile_path do
      "default" -> @default_projectile_path
      path -> path
    end

    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile} <- MasterData.get_projectile(path, projectile_id, weapon.actor)
    do
      position = Transform.offset(transform, @offset)
      rotation = target_position
                 |> Vector2.sub(position)
                 |> Vector2.to_rotation

      projectile = put_in(projectile.transform.component_data.position, position)
      projectile = put_in(projectile.transform.component_data.rotation, rotation)
      projectile = put_in(projectile.destination.component_data.target, {:some, target_position})

      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

end
