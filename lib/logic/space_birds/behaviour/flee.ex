defmodule SpaceBirds.Behaviour.Flee do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Movement
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.State.Arena
  use SpaceBirds.Behaviour.Node

  @type state :: :running
    | :success
    | :failure

  @type t :: %{
    target: Tag.tag | [Tag.tag],
    scan_distance: number,
    target_distance: number,
    state: state
  }

  defstruct target: "default",
    scan_distance: 0,
    target_distance: 0,
    state: :failure

  @impl(Node)
  def init(node, _, _, _) do
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{}, &1))}
  end

  @impl(Node)
  def select(node, component, arena) do
    with [_ | _] = actors <- Tag.find_by_tag_without_self(arena, node.node_data.target, component.actor),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      distance = Transform.distance_to(transform, closest_target)

      node.node_data.state
      |> verify_scan_distance(node.node_data.scan_distance, distance)
      |> verify_target_distance(node.node_data.target_distance, distance)
      |> (fn
        :running -> {:running, node}
        state -> state
      end).()
    else
      _ ->
        :success
    end
  end

  @impl(Node)
  def run(node, component, arena) do
    with [_ | _] = actors <- Tag.find_by_tag_without_self(arena, node.node_data.target, component.actor),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      distance = Transform.distance_to(transform, closest_target)

      node = update_in(node.node_data.state, fn state ->
        state
        |> verify_scan_distance(node.node_data.scan_distance, distance)
        |> verify_target_distance(node.node_data.target_distance, distance)
      end)

      if node.node_data.state == :running do
        {:ok, arena} = move(transform, closest_target, arena)
        {:ok, node, arena}
      else
        {:ok, node, arena}
      end
    else
      _ ->
        {:ok, node, arena} 
    end
  end

  @impl(Node)
  def reset(node, _component, _arena) do
    {:ok, put_in(node.node_data.state, :failure)}
  end

  defp move(transform, target_transform, arena) do
    with {:ok, movement} <- Components.fetch(arena.components, :movement, transform.actor),
         {:ok, transform} <- Transform.look_away_from(transform, target_transform),
         {:ok, arena} <- Arena.update_component(arena, transform, fn _ -> {:ok, transform} end),
         {:ok, _distance, arena} <- Movement.move_forward(movement, arena)
    do
      {:ok, arena}
    else
      _ ->
        {:ok, arena}
    end
  end

  defp verify_scan_distance(:running, _, _) do
    :running
  end

  defp verify_scan_distance(_, scan_distance, distance) do
    if distance <= scan_distance do
      :running
    else
      :success
    end
  end

  defp verify_target_distance(:running, target_distance, distance) do
    if distance >= target_distance do
      :success
    else
      :running
    end
  end

  defp verify_target_distance(state, _, _) do
    state
  end

end
