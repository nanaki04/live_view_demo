defmodule SpaceBirds.Behaviour.Chase do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Movement
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.State.Arena
  use SpaceBirds.Behaviour.Node

  @type state :: :running
    | :success
    | :failure

  @type t :: %{
    target: Tag.tag | [Tag.tag],
    scan_distance: number,
    target_distance: number,
    state: state,
    distance_until_giveup: number,
    lerp: {:some, %{
      curve: ProgressOverTime.curve,
      speed: number
    }} | :none
  }

  defstruct target: "default",
    scan_distance: 0,
    target_distance: 0,
    state: :failure,
    distance_until_giveup: 0,
    lerp: :none

  @impl(Node)
  def init(node, _, _, _) do
    lerp = case Map.fetch(node.node_data, :lerp) do
      {:ok, lerp} ->
        update_in(lerp.curve, &String.to_existing_atom/1)
      _ ->
        :none
    end

    node = put_in(node.node_data.lerp, lerp)
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{}, &1))}
  end

  @impl(Node)
  def select(node, component, arena) do
    with {:ok, actors} <- Tag.find_actors_by_tag(arena, node.node_data.target),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      distance = Transform.distance_to(transform, closest_target)
      node.node_data.state
      |> verify_scan_distance(node.node_data.scan_distance, distance)
      |> verify_distance_until_giveup(node.node_data.distance_until_giveup, distance)
      |> verify_target_distance(node.node_data.target_distance, distance)
      |> (fn
        :running -> {:running, node}
        state -> state
      end).()
    else
      _ ->
        :failure
    end
  end

  @impl(Node)
  def run(node, component, arena) do
    with {:ok, actors} <- Tag.find_actors_by_tag(arena, node.node_data.target),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      distance = Transform.distance_to(transform, closest_target)

      node = update_in(node.node_data.state, fn state ->
        state
        |> verify_scan_distance(node.node_data.scan_distance, distance)
        |> verify_distance_until_giveup(node.node_data.distance_until_giveup, distance)
        |> verify_target_distance(node.node_data.target_distance, distance)
      end)

      if node.node_data.state == :running do
        {:ok, arena} = move(node.node_data.lerp, transform, closest_target, arena)
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

  defp move(:none, transform, target_transform, arena) do
    with {:ok, movement} <- Components.fetch(arena.components, :movement, transform.actor),
         {:ok, transform} <- Transform.look_at(transform, target_transform),
         {:ok, arena} <- Arena.update_component(arena, transform, fn _ -> {:ok, transform} end),
         {:ok, _distance, arena} <- Movement.move_forward(movement, arena)
    do
      {:ok, arena}
    else
      _ ->
        {:ok, arena}
    end
  end

  defp move(%{curve: curve, speed: speed}, transform, target_transform, arena) do
    with {:ok, movement} <- Components.fetch(arena.components, :movement, transform.actor),
         {:ok, transform} <- Transform.look_at_over_time(transform, target_transform, speed, curve, arena),
         {:ok, arena} <- Arena.update_component(arena, transform, fn _ -> {:ok, transform} end),
         {:ok, _distance, arena} <- Movement.move_forward(movement, arena)
    do
      {:ok, arena}
    else
      _ ->
        {:ok, arena}
    end
  end

  defp verify_scan_distance(:failure, scan_distance, distance) do
    if distance <= scan_distance do
      :running
    else
      :failure
    end
  end

  defp verify_scan_distance(state, _, _) do
    state
  end

  defp verify_target_distance(:failure, _, _) do
    :failure
  end

  defp verify_target_distance(_, target_distance, distance) do
    if distance <= target_distance do
      :success
    else
      :running
    end
  end

  defp verify_distance_until_giveup(:failure, _, _) do
    :failure
  end

  defp verify_distance_until_giveup(_, distance_until_giveup, distance) do
    if distance > distance_until_giveup do
      :failure
    else
      :running
    end
  end

end
