defmodule SpaceBirds.Components.Follow do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Edge
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Logic.ProgressOverTime
  use Component

  @type t :: %{
    required(:target) => SpaceBirds.Logic.Actor.t,
    optional(:lerp) => %{
      from: %{
        distance: number,
        speed: number
      },
      to: %{
        distance: number,
        speed: number
      },
      curve: String.t
    },
    optional(:offset) => Position.t
  }

  defstruct target: 0

  @impl(Component)
  def run(%{component_data: %{lerp: _}} = component, arena) do
    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, target_transform} <- Components.fetch(arena.components, :transform, component.component_data.target)
    do
      from = component.component_data.lerp.from
      to = component.component_data.lerp.to
      min_distance = min(to.distance, from.distance)
      max_distance = max(to.distance, from.distance)
      diff = max_distance - min_distance
      pos = transform.component_data.position
      rotation = target_transform.component_data.rotation
      target_pos = target_transform.component_data.position
      target_pos = case Map.fetch(component.component_data, :offset) do
        {:ok, offset} ->
          target_pos = Vector2.add(target_pos, offset)
          Edge.rotate(%{a: target_transform.component_data.position, b: target_pos}, rotation).b
        _ ->
          target_pos
      end

      distance = Vector2.sub(pos, target_pos)
                 |> Vector2.distance
                 |> max(min_distance)
                 |> min(max_distance)

      progress = (distance - min_distance) / diff
      speed = case component.component_data.lerp.curve do
        "sine_curve" ->
          ProgressOverTime.sine_curve(%{from: from.speed, to: to.speed}, progress)
        "inverse_sine_curve" ->
          ProgressOverTime.inverse_sine_curve(%{from: from.speed, to: to.speed}, progress)
        "exponential" ->
          ProgressOverTime.exponential(%{from: from.speed, to: to.speed}, progress)
        "inverse_exponential" ->
          ProgressOverTime.inverse_exponential(%{from: from.speed, to: to.speed}, progress)
        _ ->
          ProgressOverTime.linear(%{from: from.speed, to: to.speed}, progress)
      end

      destination = Edge.to_rotation(%{a: pos, b: target_pos})
                    |> Vector2.from_rotation
                    |> Vector2.mul(speed * arena.delta_time)
                    |> Vector2.add(pos)

      destination = if abs(Edge.distance(%{a: pos, b: destination})) > abs(Edge.distance(%{a: pos, b: target_pos})) do
        target_pos
      else
        destination
      end

      Arena.update_component(arena, transform, fn transform ->
        transform = put_in(transform.component_data.position, destination)
        case Map.fetch(component.component_data, :offset) do
          {:ok, _} ->
            put_in(transform.component_data.rotation, rotation)
          _ ->
            transform
        end
        |> ResultEx.return
      end)
    else
      _ -> {:ok, arena}
    end
  end

  def run(component, arena) do
    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, target_transform} <- Components.fetch(arena.components, :transform, component.component_data.target)
    do
      rotation = target_transform.component_data.rotation
      target_pos = target_transform.component_data.position
      target_pos = case Map.fetch(component.component_data, :offset) do
        {:ok, offset} ->
          target_pos = Vector2.add(target_pos, offset)
          Edge.rotate(%{a: target_transform.component_data.position, b: target_pos}, rotation).b
        _ ->
          target_pos
      end

      Arena.update_component(arena, transform, fn transform ->
        transform = put_in(transform.component_data.position, target_pos)
        case Map.fetch(component.component_data, :offset) do
          {:ok, _} ->
            put_in(transform.component_data.rotation, rotation)
          _ ->
            transform
        end
        |> ResultEx.return
      end)
    else
      _ -> {:ok, arena}
    end
  end

end
