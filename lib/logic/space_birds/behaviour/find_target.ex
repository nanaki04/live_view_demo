defmodule SpaceBirds.Behaviour.FindTarget do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Components.Tag
  use SpaceBirds.Behaviour.Node

  @type state :: :running
    | :success
    | :failure

  @type t :: %{
    target: Tag.tag | [Tag.tag],
    scan_distance: number,
    state: state
  }

  defstruct target: "default",
    scan_distance: 0,
    state: :failure

  @impl(Node)
  def init(node, _, _, _) do
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{}, &1))}
  end

  @impl(Node)
  def select(node, component, arena) do
    with [_ | _] = actors <- Tag.find_by_tag_without_owner(arena, node.node_data.target, component.actor),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      distance = Transform.distance_to(transform, closest_target)

      node.node_data.state
      |> verify_scan_distance(node.node_data.scan_distance, distance)
    else
      _ ->
        :failure
    end
  end

  @impl(Node)
  def reset(node, _component, _arena) do
    {:ok, put_in(node.node_data.state, :failure)}
  end

  defp verify_scan_distance(:failure, scan_distance, distance) do
    if distance <= scan_distance do
      :success
    else
      :failure
    end
  end

  defp verify_scan_distance(state, _, _) do
    state
  end

end
