defmodule SpaceBirds.Components.Movement do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Logic.Edge
  alias SpaceBirds.Logic.ProgressOverTime
  use Component

  @background_actor 1

  @min_speed 10

  @type t :: %{
    speed: %{x: number, y: number},
    bound_by_map: boolean
  }

  defstruct speed: %{x: 0, y: 0},
    bound_by_map: true

  @impl(Component)
  def run(_component, arena) do
    {:ok, arena}
  end

  @spec orbit(movement :: Component.t, target_transform :: Component.t, radius :: number, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def orbit(component, target_transform, radius, arena) do
    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(readonly_stats.status, :stunned)
    do
      speed = Vector2.distance(component.component_data.speed)
              |> Kernel.+(arena.delta_time * readonly_stats.acceleration)
              |> apply_drag(readonly_stats.drag, arena.delta_time)
              |> min(readonly_stats.top_speed)
              |> max(@min_speed)

      position = transform.component_data.position
      target_position = target_transform.component_data.position
      distance = Edge.distance(%{a: target_position, b: position})
      diff = Vector2.sub(position, target_position)
      progress = abs(distance - radius) * arena.delta_time * 0.1
                 |> min(1.0)
                 |> max(0.0)

      adjustment_x = ProgressOverTime.exponential(%{from: 0, to: diff.x}, progress)
      adjustment_y = ProgressOverTime.exponential(%{from: 0, to: diff.y}, progress)
      offset = %{x: adjustment_x, y: adjustment_y}

      position = if radius > distance, do: Vector2.add(position, offset), else: Vector2.sub(position, offset)
      rotated_edge = Edge.rotate_by_distance(
        %{a: target_position, b: position},
        speed * arena.delta_time
      )

      rotation = Edge.to_rotation(rotated_edge)
      unit_vector = Vector2.from_rotation(rotation)

      component = put_in(component.component_data.speed, Vector2.mul(unit_vector, speed))
      transform = put_in(transform.component_data.position, rotated_edge.b)

      {:ok, arena} = Arena.update_component(arena, component, fn _ -> {:ok, component} end)
      Arena.update_component(arena, transform, fn _ -> {:ok, transform} end)
    else
      _ ->
        {:ok, arena}
    end
  end

  @spec move_forward(t, Arena.t, :unlimited | number) :: {:ok, number, Arena.t} | {:error, String.t}
  def move_forward(component, arena, distance_limit \\ :unlimited) do
    distance = 0

    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(readonly_stats.status, :stunned)
    do
      unit_vector = Vector2.from_rotation(transform.component_data.rotation)

      speed_offset = unit_vector
                     |> Vector2.mul(readonly_stats.acceleration)
                     |> Vector2.mul(arena.delta_time)

      component = update_in(component.component_data.speed, fn speed ->
        speed
        |> Vector2.add(speed_offset)
        |> apply_drag(readonly_stats.drag, arena.delta_time)
        |> cap_top_speed(readonly_stats.top_speed, unit_vector)
        |> discard_minimal_speed
      end)

      offset = Vector2.mul(component.component_data.speed, arena.delta_time)

      distance = Vector2.distance(offset)
      distance = case distance_limit do
        :unlimited -> distance
        max_distance -> min(distance, max_distance)
      end

      offset = Vector2.mul(unit_vector, distance)
      {:ok, position} = Vector2.add(transform.component_data.position, offset)
                        |> cap_map_bounderies(transform, component, arena)

      transform = put_in(transform.component_data.position, position)

      {:ok, arena} = Arena.update_component(arena, component, fn _ -> {:ok, component} end)
      {:ok, arena} = Arena.update_component(arena, transform, fn _ -> {:ok, transform} end)
      {:ok, distance, arena}
    else
      _ ->
        {:ok, distance, arena}
    end
  end

  defp apply_drag(%{x: _, y: _} = speed, drag, delta_time) do
    Vector2.mul(speed, 1 / (1 + drag * delta_time))
  end

  defp apply_drag(speed, drag, delta_time) do
    speed * (1 / (1 + drag * delta_time))
  end

  defp cap_top_speed(speed, top_speed, unit_vector) do
    max_limit = unit_vector
                |> Vector2.abs
                |> Vector2.mul(top_speed)

    min_limit = Vector2.mul(max_limit, -1)

    speed
    |> Vector2.max(min_limit)
    |> Vector2.min(max_limit)
  end

  defp discard_minimal_speed(%{x: x, y: y}) do
    %{
      x: (if abs(x) < @min_speed, do: 0, else: x),
      y: (if abs(y) < @min_speed, do: 0, else: y)
    }
  end

  defp cap_map_bounderies(position, _, %{component_data: %{bound_by_map: false}}, _) do
    {:ok, position}
  end

  defp cap_map_bounderies(%{x: x, y: y}, transform, %{component_data: %{bound_by_map: true}}, arena) do
    with {:ok, background_transform} <- Components.fetch(arena.components, :transform, @background_actor)
    do
      min_x = -background_transform.component_data.size.width / 2 + transform.component_data.size.width / 2
      max_x = background_transform.component_data.size.width / 2 - transform.component_data.size.width / 2
      min_y = -background_transform.component_data.size.height / 2 + transform.component_data.size.height / 2
      max_y = background_transform.component_data.size.height / 2 - transform.component_data.size.height / 2

      x = x
          |> max(min_x)
          |> min(max_x)

      y = y
          |> max(min_y)
          |> min(max_y)

      {:ok, %{x: x, y: y}}
    else
      error -> error
    end
  end
end
