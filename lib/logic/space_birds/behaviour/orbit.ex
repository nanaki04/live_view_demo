defmodule SpaceBirds.Behaviour.Orbit do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Movement
  use SpaceBirds.Behaviour.Node

  @type state :: :running
    | :success
    | :failure

  @type t :: %{
    target: Actor.t,
    radius: number,
    state: state,
  }

  defstruct target: 0,
    radius: 0,
    state: :failure

  @impl(Node)
  def init(node, _, _, _) do
    {:ok, update_in(node.node_data, & Map.merge(%__MODULE__{}, &1))}
  end

  def select(node, _component, _arena) do
    {:running, node}
  end

  @impl(Node)
  def run(node, component, arena) do
    with {:ok, target_transform} <- Components.fetch(arena.components, :transform, node.node_data.target),
         {:ok, movement} <- Components.fetch(arena.components, :movement, component.actor)
    do
      {:ok, arena} = Movement.orbit(movement, target_transform, node.node_data.radius, arena)
      {:ok, node, arena}
    else
      _ ->
        {:ok, node, arena} 
    end
  end

  @impl(Node)
  def reset(node, _component, _arena) do
    {:ok, put_in(node.node_data.state, :failure)}
  end

end
