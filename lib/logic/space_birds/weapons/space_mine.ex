defmodule SpaceBirds.Weapons.SpaceMine do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "space_mine"

  @type t :: %{
    enhancements: [term],
    path: String.t
  }

  defstruct enhancements: [],
    path: "default"

  @impl(Weapon)
  def on_channel(weapon, 0, arena) do
    spawn_projectile(weapon, arena)
  end

  def on_channel(_, _, arena) do
    {:ok, arena}
  end

  defp spawn_projectile(weapon, arena) do
    path = if weapon.weapon_data.path == "default", do: @default_path, else: weapon.weapon_data.path
    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile} <- MasterData.get_projectile(path, projectile_id, weapon.actor)
    do
      projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)
      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

end
