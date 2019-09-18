defmodule SpaceBirds.Weapons.RailGun do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_projectile_path "rail_gun"

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
      rotation = target_position
                 |> Vector2.sub(transform.component_data.position)
                 |> Vector2.to_rotation

      position = Vector2.from_rotation(rotation)
                 |> Vector2.mul(projectile.transform.component_data.size.height / 2)
                 |> Vector2.add(transform.component_data.position)

      projectile = put_in(projectile.transform.component_data.position, position)
      projectile = put_in(projectile.transform.component_data.rotation, rotation)

      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

end
