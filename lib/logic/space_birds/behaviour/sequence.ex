defmodule SpaceBirds.Behaviour.Sequence do
  alias SpaceBirds.Behaviour.Node
  use Node

  @type t :: %{
    children: [Node.t]
  }

  defstruct children: []

  @impl(Node)
  def init(node, id, component, arena) do
    SpaceBirds.Behaviour.Selector.init(node, id, component, arena)
  end

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
        |> ResultEx.or_else(child)
      end)
    end)
    |> ResultEx.return
  end

  @impl(Node)
  def sync_running_node(node, running_node) do
    update_in(node.node_data.children, fn children ->
      Enum.map(children, fn child ->
        Node.sync_running_node(child, running_node)
      end)
    end)
  end

end
