defmodule SpaceBirds.Behaviour.DestroySelf do
  alias SpaceBirds.State.Arena
  use SpaceBirds.Behaviour.Node

  def select(node, _component, _arena) do
    {:running, node}
  end

  @impl(Node)
  def run(node, component, arena) do
    {:ok, arena} = Arena.remove_actor(arena, component.actor)

    {:ok, node, arena}
  end

end
