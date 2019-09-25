defmodule SpaceBirds.Weapons.LaserBeam do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_projectile_path "laser_beam"

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

      {:ok, projectile} = Team.copy_team(projectile, arena, weapon.actor)
      projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)
      projectile = put_in(projectile.transform.component_data.rotation, rotation)
      projectile = put_in(projectile.destination.component_data.target, {:some, target_position})

      {:ok, arena} = Arena.add_actor(arena, projectile)

      Arena.update_component(arena, :animation_player, projectile_id, fn animation_player ->
        AnimationPlayer.play_animation(animation_player, "laser_beam")
      end)
    else
      _ ->
        {:ok, arena}
    end
  end

end
