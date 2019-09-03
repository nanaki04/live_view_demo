defmodule SpaceBirds.Behaviour.MoveForward do
  alias SpaceBirds.Components.Movement
  alias SpaceBirds.Components.Components
  use SpaceBirds.Behaviour.Node

  @type t :: %{
    distance: :unlimited | number,
    distance_left: :unlimited | number
  }

  defstruct distance: :unlimited,
    distance_left: :unlimited

  @impl(Node)
  def init(node, _, _component, _arena) do
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{distance_left: &1.distance}, &1))}
  end

  @impl(Node)
  def select(node, _component, _arena) do
    case node.node_data.distance_left do
      :unlimited ->
        {:running, node}
      distance_left when distance_left > 0 ->
        {:running, node}
      _ ->
        :success
      # TODO maybe fail on collision
    end
  end

  @impl(Node)
  def run(node, component, arena) do
    with {:ok, movement} <- Components.fetch(arena.components, :movement, component.actor)
    do
      {:ok, distance, arena} =
        Movement.move_forward(movement, arena, node.node_data.distance_left)

      node = update_in(node.node_data.distance_left, & &1 - distance)

      {:ok, node, arena}
    else
      _ ->
        {:ok, node, arena}
    end
  end

  @impl(Node)
  def reset(node, _component, _arena) do
    put_in(node.node_data.distance_left, node.node_data.distance)
    |> ResultEx.return
  end

end
