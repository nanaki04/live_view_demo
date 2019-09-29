defmodule SpaceBirds.Components.MovementController do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.VisualEffectStack
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Math
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.MasterData
  use Component

  @cross_speed_coefficient Math.sin(45)

  @background_actor 1

  @min_speed 10

  @type t :: %{
    owner: Players.player_id,
    top_speed: number,
    drag: number,
    speed: %{x: number, y: number},
    acceleration: number,
    direction: %{x: number, y: number},
    bound_by_map: boolean,
    visual_effects: [MasterData.visual_effect_type]
  }

  defstruct owner: 0,
    top_speed: 1,
    drag: 1,
    speed: %{x: 0, y: 0},
    acceleration: 1,
    direction: %{x: 0, y: 0},
    bound_by_map: true,
    visual_effects: []

  defguardp is_cross_angle(v2) when :erlang.map_get(:x, v2) != 0
    and :erlang.map_get(:x, v2) != 0.0
    and :erlang.map_get(:y, v2) != 0
    and :erlang.map_get(:y, v2) != 0.0

  @impl(Component)
  def run(component, arena) do
    actor = component.actor

    with {:ok, stats} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(stats.component_data.status, :stunned),
         :none <- Stats.find_status(stats, :channeling)
    do
      move(actor, stats.component_data, component, arena)
    else
      _ ->
        # MEMO: does not actually turn, but consumes key presses to prevent corrupt keypress / movement status
        component = update_direction(actor, component, arena)
        Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    end
  end

  defp update_direction(actor, component, arena) do
    owner = component.component_data.owner

    actions = Enum.reduce(arena.actions, [], fn
      %{sender: {:player, ^owner}} = action, actions ->
        [action | actions]
      %{sender: {:actor, ^actor}} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)

    Enum.reduce(actions, component, fn
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
  end

  defp move(actor, readonly_stats, component, arena) do
    component = update_direction(actor, component, arena)

    speed_offset = calculate_speed_offset(
      component.component_data.direction,
      readonly_stats.acceleration * arena.delta_time
    )

    component = update_in(component.component_data.speed, fn speed ->
      speed
      |> v2_add(speed_offset)
      |> apply_drag(readonly_stats.drag, arena.delta_time)
      |> cap_top_speed(readonly_stats.top_speed)
      |> discard_minimal_speed
    end)

    {:ok, arena} = Arena.update_component(arena, :transform, component.actor, fn transform ->
      transform = put_in(
        transform.component_data.rotation,
        direction_to_rotation(component.component_data.direction, transform.component_data.rotation)
      )

      speed = calculate_speed(component.component_data.speed)
      {:ok, position} = v2_add(transform.component_data.position, v2_mul(speed, arena.delta_time))
                        |> cap_map_bounderies(transform, component, arena)

      transform = put_in(transform.component_data.position, position)

      {:ok, transform}
    end)

    {:ok, arena} = Arena.update_component(arena, component, fn _ -> {:ok, component} end)

    play_visual_effects(component, arena)
  end

  defp play_visual_effects(component, arena) do
    Enum.reduce(component.component_data.visual_effects, {:ok, arena}, fn
      visual_effect_type, {:ok, arena} ->
        case Vector2.round(component.component_data.speed) do
          %{x: 0, y: 0} ->
            {:ok, effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
            VisualEffectStack.remove_visual_effect(effect_stack, visual_effect_type, arena)
          _ ->
            {:ok, effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
            unless VisualEffectStack.owns?(effect_stack, visual_effect_type) do
              {:ok, arena} = VisualEffectStack.add_visual_effect(effect_stack, visual_effect_type, arena)
              {:ok, effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
              {:some, effect_id} = VisualEffectStack.find(effect_stack, visual_effect_type)
              Arena.update_component(arena, :follow, effect_id, fn follow ->
                {:ok, put_in(follow.component_data.target, component.actor)}
              end)
            else
              {:ok, arena}
            end
        end
      _, error ->
        error
    end)
  end

  defp direction_to_rotation(%{x: 0, y: 0}, rotation), do: rotation
  defp direction_to_rotation(%{x: 0, y: -1}, _), do: 0
  defp direction_to_rotation(%{x: 1, y: -1}, _), do: 45
  defp direction_to_rotation(%{x: 1, y: 0}, _), do: 90
  defp direction_to_rotation(%{x: 1, y: 1}, _), do: 135
  defp direction_to_rotation(%{x: 0, y: 1}, _), do: 180
  defp direction_to_rotation(%{x: -1, y: 1}, _), do: 225
  defp direction_to_rotation(%{x: -1, y: 0}, _), do: 270
  defp direction_to_rotation(%{x: -1, y: -1}, _), do: 315

  defp calculate_speed_offset(direction, acceleration) when is_cross_angle(direction) do
    v2_mul(direction, @cross_speed_coefficient * acceleration)
  end

  defp calculate_speed_offset(direction, acceleration) do
    v2_mul(direction, acceleration)
  end

  defp apply_drag(speed, drag, delta_time) when is_cross_angle(speed) do
    v2_mul(speed, 1 / (1 + (drag * @cross_speed_coefficient * 1 * delta_time)))
  end

  defp apply_drag(speed, drag, delta_time) do
    v2_mul(speed, 1 / (1 + drag * 1 * delta_time))
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
