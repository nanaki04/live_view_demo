defmodule SpaceBirds.Weapons.LaserBeam do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  use Weapon

  @default_projectile_path "lib/master_data/space_birds/laser_beam.json"

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

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, json} <- File.read(path),
         {:ok, projectile} <- Jason.decode(json, keys: :atoms)
    do
      projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)
      projectile = put_in(projectile.transform.component_data.rotation, transform.component_data.rotation)
      projectile = put_in(projectile.destination.component_data.target, {:some, target_position})

      Arena.add_actor(arena, projectile)
    else
      _error ->
        {:ok, arena}
    end
  end

end
