defmodule SpaceBirds.Weapons.FireBolt do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_projectile_path "fire_bolt"

  @type t :: %{
    projectile_base_path: String.t,
    enhancements: [term]
  }

  defstruct projectile_base_path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(weapon, target_position, arena) do
    base_path = case weapon.weapon_data.projectile_base_path do
      "default" -> @default_projectile_path
      path -> path
    end

    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile3} <- MasterData.get_projectile("#{base_path}_03", projectile_id, weapon.actor),
         {:ok, projectile2} <- MasterData.get_projectile("#{base_path}_02", projectile_id + 1, weapon.actor),
         {:ok, projectile1} <- MasterData.get_projectile("#{base_path}_01", projectile_id + 2, weapon.actor)
    do
      rotation = target_position
                 |> Vector2.sub(transform.component_data.position)
                 |> Vector2.to_rotation

      [projectile3, projectile2, projectile1] = Enum.map([projectile3, projectile2, projectile1], fn projectile ->

        projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)
        projectile = put_in(projectile.transform.component_data.rotation, rotation)
        put_in(projectile.destination.component_data.target, {:some, target_position})
      end)

      {:ok, arena} = Arena.add_actor(arena, projectile3)
      {:ok, arena} = Arena.add_actor(arena, projectile2)
      Arena.add_actor(arena, projectile1)
    else
      _ ->
        {:ok, arena}
    end
  end

end
