defmodule SpaceBirds.Weapons.PlasmaOverload do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "plasma_overload"

  @type t :: %{
    charges: number,
    enhancements: [term],
    path: String.t,
    projectile_count: number
  }

  defstruct charges: 5,
    enhancements: [],
    path: "default",
    projectile_count: 0

  @impl(Weapon)
  def fire(weapon, _, arena) do
    weapon = put_in(weapon.weapon_data.projectile_count, 0)
    {:ok, arena} = update_weapon(weapon, arena)
    start_channeling(weapon, arena)
  end

  @impl(Weapon)
  def on_channel(weapon, channel_time_remaining, arena) do
    channel_time = weapon.channel_time
    progress = (channel_time - channel_time_remaining) / channel_time

    next_hit_count = ProgressOverTime.linear(%{from: 0, to: weapon.weapon_data.charges}, progress)
                     |> round

    if next_hit_count > weapon.weapon_data.projectile_count && next_hit_count <= weapon.weapon_data.charges do
      weapon = update_in(weapon.weapon_data.projectile_count, &(&1 + 1))

      {:ok, arena} = update_weapon(weapon, arena)
      spawn_projectile(weapon, arena)
    else
      {:ok, arena}
    end
  end

  defp spawn_projectile(weapon, arena) do
    path = if weapon.weapon_data.path == "default", do: @default_path, else: weapon.weapon_data.path
    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile} <- MasterData.get_projectile(path, projectile_id, weapon.actor)
    do
      rotation = case rem(weapon.weapon_data.projectile_count, 10) do
        0 -> 135
        1 -> 225
        2 -> 45
        3 -> 315
        4 -> 175
        5 -> 290
        6 -> 215
        7 -> 15
        8 -> 145
        9 -> 350
      end

      projectile = put_in(projectile.transform.component_data.rotation, rotation)
      projectile = put_in(projectile.transform.component_data.position, transform.component_data.position)

      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

end
