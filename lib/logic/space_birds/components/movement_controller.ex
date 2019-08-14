defmodule SpaceBirds.Components.MovementController do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  use Component

  @cross_speed_coefficient :math.sin(45 / (180 / :math.pi))

  @background_actor 1

  @min_speed 10

  @type t :: %{
    owner: Players.player_id,
    top_speed: number,
    drag: number,
    speed: %{x: number, y: number},
    acceleration: number,
    direction: %{x: number, y: number},
    bound_by_map: boolean
  }

  defstruct owner: 0,
    top_speed: 1,
    drag: 1,
    speed: %{x: 0, y: 0},
    acceleration: 1,
    direction: %{x: 0, y: 0},
    bound_by_map: true

  defguardp is_cross_angle(v2) when :erlang.map_get(:x, v2) != 0
    and :erlang.map_get(:x, v2) != 0.0
    and :erlang.map_get(:y, v2) != 0
    and :erlang.map_get(:y, v2) != 0.0

  @impl(Component)
  def run(component, arena) do
    owner = component.component_data.owner
    actor = component.actor

    actions = Enum.reduce(arena.actions, [], fn
      %{sender: {:player, ^owner}} = action, actions ->
        [action | actions]
      %{sender: {:actor, ^actor}} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)

    component = Enum.reduce(actions, component, fn
      %{name: :move_up_start}, component ->
        update_in(component.component_data.direction.y, & max(&1 - 1, -1))
      %{name: :move_up_stop}, component ->
        update_in(component.component_data.direction.y, & min(&1 + 1, 1))
      %{name: :move_down_start}, component ->
        update_in(component.component_data.direction.y, & min(&1 + 1, 1))
      %{name: :move_down_stop}, component ->
        update_in(component.component_data.direction.y, & max(&1 - 1, -1))
      %{name: :move_left_start}, component ->
        update_in(component.component_data.direction.x, & max(&1 - 1, -1))
      %{name: :move_left_stop}, component ->
        update_in(component.component_data.direction.x, & min(&1 + 1, 1))
      %{name: :move_right_start}, component ->
        update_in(component.component_data.direction.x, & min(&1 + 1, 1))
      %{name: :move_right_stop}, component ->
        update_in(component.component_data.direction.x, & max(&1 - 1, -1))
      _, component ->
        component
    end)

    speed_offset = calculate_speed_offset(
      component.component_data.direction,
      component.component_data.acceleration
    )

    component = update_in(component.component_data.speed, fn speed ->
      speed
      |> v2_add(speed_offset)
      |> apply_drag(component.component_data.drag)
      |> cap_top_speed(component.component_data.top_speed)
      |> discard_minimal_speed
    end)

    {:ok, arena} = Arena.update_component(arena, :transform, component.actor, fn transform ->
      transform = put_in(transform.component_data.rotation, direction_to_rotation(component.component_data.direction))

      speed = calculate_speed(component.component_data.speed)
      {:ok, position} = v2_add(transform.component_data.position, v2_mul(speed, arena.delta_time))
                        |> cap_map_bounderies(transform, component, arena)

      transform = put_in(transform.component_data.position, position)

      {:ok, transform}
    end)

    {:ok, arena} = Arena.update_component(arena, component, fn _ -> {:ok, component} end)

    {:ok, arena}
  end

  defp direction_to_rotation(%{x: 0, y: 0}), do: 0
  defp direction_to_rotation(%{x: 0, y: -1}), do: 0
  defp direction_to_rotation(%{x: 1, y: -1}), do: 45
  defp direction_to_rotation(%{x: 1, y: 0}), do: 90
  defp direction_to_rotation(%{x: 1, y: 1}), do: 135
  defp direction_to_rotation(%{x: 0, y: 1}), do: 180
  defp direction_to_rotation(%{x: -1, y: 1}), do: 225
  defp direction_to_rotation(%{x: -1, y: 0}), do: 270
  defp direction_to_rotation(%{x: -1, y: -1}), do: 315

  defp calculate_speed_offset(direction, acceleration) when is_cross_angle(direction) do
    v2_mul(direction, @cross_speed_coefficient * acceleration)
  end

  defp calculate_speed_offset(direction, acceleration) do
    v2_mul(direction, acceleration)
  end

  defp apply_drag(speed, drag) when is_cross_angle(speed) do
    v2_mul(speed, 1 / (1 + (drag * @cross_speed_coefficient * 0.1)))
  end

  defp apply_drag(speed, drag) do
    v2_mul(speed, 1 / (1 + drag * 0.1))
  end

  defp calculate_speed(speed) when is_cross_angle(speed), do: v2_mul(speed, @cross_speed_coefficient)
  defp calculate_speed(speed), do: speed

  defp v2_mul(%{x: x, y: y}, n), do: %{x: x * n, y: y * n}
  defp v2_add(%{x: x1, y: y1}, %{x: x2, y: y2}), do: %{x: x1 + x2, y: y1 + y2}

  defp cap_top_speed(%{x: x, y: y}, top_speed) do
    x = max(x, -top_speed)
        |> min(top_speed)

    y = max(y, -top_speed)
        |> min(top_speed)

    %{x: x, y: y}
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
