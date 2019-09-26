defmodule SpaceBirds.Components.PlayerSpawner do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Rotation
  use Component

  @type t :: %{
    spawn_positions: [Position.t],
    rotations: [Rotation.t],
    respawn_time: number,
    time_until_respawn: number
  }

  defstruct spawn_positions: [],
    rotations: [0, 45, 90, 135, 180, 225, 270, 315],
    respawn_time: 0,
    time_until_respawn: 0

  @impl(Component)
  def init(component, arena) do
    component_data = Map.merge(%__MODULE__{}, component.component_data)
    Arena.update_component(arena, component, fn _ ->
      {:ok, put_in(component.component_data, component_data)}
    end)
  end

  @impl(Component)
  def run(component, arena) do
    with {:ok, %{component_data: %{is_defeated?: true}}} <- Components.fetch(arena.components, :defeatable, component.actor)
    do
      time_until_respawn = component.component_data.time_until_respawn
      time_after_tick = max(0, time_until_respawn - arena.delta_time * 1000)

      {:ok, arena} = if time_until_respawn > 1000 && time_after_tick <= 1000 do
        Arena.update_component(arena, :animation_player, component.actor, fn animation_player ->
          AnimationPlayer.play_animation(animation_player, "fade_in")
        end)
      else
        {:ok, arena}
      end

      component = put_in(component.component_data.time_until_respawn, time_after_tick)
      Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    else
      _ ->
        component = put_in(component.component_data.time_until_respawn, component.component_data.respawn_time)
        Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    end
  end

  @spec set_spawn_position(Component.t | Actor.t, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def set_spawn_position(%{actor: _} = component, arena) do
    Arena.update_component(arena, :transform, component.actor, fn transform ->
      roll = :rand.uniform(length(component.component_data.spawn_positions)) - 1
      pos = Enum.at(component.component_data.spawn_positions, roll)

      roll = :rand.uniform(length(component.component_data.rotations)) - 1
      rotation = Enum.at(component.component_data.rotations, roll)

      transform = put_in(transform.component_data.position, pos)
      {:ok, put_in(transform.component_data.rotation, rotation)}
    end)
  end

  def set_spawn_position(actor, arena) do
    with {:ok, spawner} <- Components.fetch(arena.components, :player_spawner, actor)
    do
      set_spawn_position(spawner, arena)
    else
      _ ->
        {:ok, arena}
    end
  end
end
