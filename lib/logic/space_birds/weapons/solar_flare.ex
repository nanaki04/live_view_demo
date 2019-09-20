defmodule SpaceBirds.Weapons.SolarFlare do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_path_phase_1 "solar_flare_01"
  @default_path_phase_2 "solar_flare_02"
  @default_path_phase_3 "solar_flare_03"

  @type t :: %{
    enhancements: [term],
    phase_1_path: String.t,
    phase_2_path: String.t,
    phase_3_path: String.t,
    phase: number,
    active_projectile: :none | {:some, Actor.t}
  }

  defstruct enhancements: [],
    phase_1_path: "default",
    phase_2_path: "default",
    phase_3_path: "default",
    phase: 0,
    active_projectile: :none


  @impl(Weapon)
  def fire(weapon, target_position, arena) do
    weapon = put_in(weapon.weapon_data.phase, 0)
    {:ok, arena} = update_weapon(weapon, arena)

    Arena.update_component(arena, :transform, weapon.actor, fn transform ->
      Transform.look_at_point(transform, target_position)
    end)
  end

  @impl(Weapon)
  def on_channel(weapon, channel_time_remaining, arena) do
    channel_time = weapon.channel_time
    progress = (channel_time - channel_time_remaining) / channel_time

    next_phase = ProgressOverTime.linear(%{from: 1, to: 4}, progress)
                 |> floor

    if next_phase > weapon.weapon_data.phase && next_phase <= 3 do
      weapon = update_in(weapon.weapon_data.phase, &(&1 + 1))
      path = case next_phase do
        1 ->
          path = weapon.weapon_data.phase_1_path
          if path == "default", do: @default_path_phase_1, else: path
        2 ->
          path = weapon.weapon_data.phase_2_path
          if path == "default", do: @default_path_phase_2, else: path
        3 ->
          path = weapon.weapon_data.phase_3_path
          if path == "default", do: @default_path_phase_3, else: path
      end

      {:ok, arena} = update_weapon(weapon, arena)
      spawn_projectile(weapon, path, arena)
    else
      {:ok, arena}
    end
  end

  @impl(Weapon)
  def on_channel_ended(%{weapon_data: %{active_projectile: {:some, projectile}}}, arena) do
    Arena.remove_actor(arena, projectile)
  end

  def on_channel_ended(_, arena) do
    {:ok, arena}
  end

  defp spawn_projectile(weapon, path, arena) do
    projectile_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, projectile} <- MasterData.get_projectile(path, projectile_id, weapon.actor)
    do
      rotation = transform.component_data.rotation
      position = Vector2.from_rotation(rotation)
                 |> Vector2.mul(projectile.transform.component_data.size.height / 2)
                 |> Vector2.add(transform.component_data.position)

      projectile = put_in(projectile.transform.component_data.rotation, rotation)
      projectile = put_in(projectile.transform.component_data.position, position)

      weapon = put_in(weapon.weapon_data.active_projectile, projectile_id)
      {:ok, arena} = update_weapon(weapon, arena)

      Arena.add_actor(arena, projectile)
    else
      _ ->
        {:ok, arena}
    end
  end

end
