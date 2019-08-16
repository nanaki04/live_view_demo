defmodule SpaceBirds.Behaviour.Sequence do
  alias SpaceBirds.Behaviour.Node
  use Node

  @type t :: %{
    children: [Node.t]
  }

  defstruct children: []

  @impl(Node)
  def select(node, component, arena) do
    Enum.reduce(node.node_data.children, :success, fn
      node, :success ->
        Node.select(node, component, arena)
      _node, result ->
        result
    end)
  end

  @impl(Node)
  def reset(node, component, arena) do
    update_in(node.node_data.children, fn children ->
      Enum.map(children, fn child ->
        Node.reset(child, component, arena)
      end)
    end)
    |> ResultEx.return
  end

end
