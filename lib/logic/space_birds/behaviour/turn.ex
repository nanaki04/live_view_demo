defmodule SpaceBirds.Behaviour.Turn do
  alias SpaceBirds.Logic.Rotation
  alias SpaceBirds.State.Arena
  use SpaceBirds.Behaviour.Node

  @type t :: %{
    degrees: number,
    rotation_left: number
  }

  defstruct degrees: 90,
    rotation_left: 90

  @impl(Node)
  def init(node, _, _component, _arena) do
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{rotation_left: &1.degrees}, &1))}
  end

  @impl(Node)
  def select(%{node_data: %{rotation_left: 0}}, _component, _arena) do
    :success
  end

  def select(node, _component, _arena) do
    {:running, node}
  end

  @impl(Node)
  def run(node, component, arena) do
    {:ok, arena} = Arena.update_component(arena, :transform, component.actor, fn transform ->
      {:ok, update_in(transform.component_data.rotation, & Rotation.add(&1, node.node_data.degrees))}
    end)

    node = put_in(node.node_data.rotation_left, 0)

    {:ok, node, arena}
  end

  @impl(Node)
  def reset(node, _, _) do
    {:ok, put_in(node.node_data.rotation_left, node.node_data.degrees)}
  end

end
