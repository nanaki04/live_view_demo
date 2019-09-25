defmodule SpaceBirds.Weapons.Drones do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Weapon

  @default_path "drone"

  @type t :: %{
    enhancements: [term],
    path: String.t,
    max_drone_count: number,
    drones: [Actor.t],
    spawn_interval: number,
    time_until_next_spawn: number
  }

  defstruct enhancements: [],
    path: "default",
    max_drone_count: 3,
    drones: [],
    spawn_interval: 30000,
    time_until_next_spawn: 30000

  @impl(Weapon)
  def run(weapon, arena) do
    weapon = update_drones(weapon, arena)
             |> cool_down_spawn_time(arena)
    {:ok, {weapon, arena}} = spawn_drone(weapon, arena)
    {:ok, {weapon, arena}} = cool_down(weapon, arena)
    update_weapon(weapon, arena)
  end

  @impl(Weapon)
  def fire(%{weapon_data: %{drones: []}} = weapon, _, arena) do
    weapon = put_in(weapon.cooldown_remaining, 0)
    update_weapon(weapon, arena)
  end

  def fire(_weapon, _target_position, arena) do
    # TODO pass order to drones
    {:ok, arena}
  end

  defp update_drones(weapon, arena) do
    update_in(weapon.weapon_data.drones, fn drones ->
      Enum.filter(drones, fn drone ->
        case Components.fetch(arena.components, :transform, drone) do
          {:ok, _} -> true
          _ -> false
        end
      end)
    end)
  end

  defp cool_down_spawn_time(%{weapon_data: %{drones: drones, max_drone_count: max_drones}} = weapon, arena)
    when length(drones) < max_drones
  do
    update_in(weapon.weapon_data.time_until_next_spawn, &(&1 - arena.delta_time * 1000))
  end

  defp cool_down_spawn_time(weapon, _) do
    weapon
  end

  defp spawn_drone(%{weapon_data: %{time_until_next_spawn: time_until_next_spawn}} = weapon, arena)
    when time_until_next_spawn > 0
  do
    {:ok, {weapon, arena}}
  end

  defp spawn_drone(weapon, arena) do
    path = if weapon.weapon_data.path == "default", do: @default_path, else: weapon.weapon_data.path
    drone_id = arena.last_actor_id + 1

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, drone} <- MasterData.get_prototype(path, drone_id)
    do
      position = Vector2.add(transform.component_data.position, %{x: 250, y: 0}) # TODO auto lerp to orbit height
      drone = put_in(drone.transform.component_data.position, position)
      drone = put_in(drone.owner.component_data.owner, weapon.actor)
      {:ok, drone} = Team.copy_team(drone, arena, weapon.actor)

      # TODO there must be a better way
      drone = update_in(drone.behaviour.component_data.node_tree.node_data.children, fn [control_node1, control_node2] ->
        [control_node1, update_in(control_node2.node_data.children, fn [flee, orbit] ->
          [flee, update_in(orbit.node_data, fn node_data -> Map.put(node_data, :target, weapon.actor) end)]
        end)]
      end)

      {:ok, arena} = Arena.add_actor(arena, drone)
      weapon = update_in(weapon.weapon_data.drones, &[drone_id | &1])
      weapon = put_in(weapon.weapon_data.time_until_next_spawn, weapon.weapon_data.spawn_interval)

      {:ok, {weapon, arena}}
    else
      _ ->
        {:ok, {weapon, arena}}
    end
  end

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
