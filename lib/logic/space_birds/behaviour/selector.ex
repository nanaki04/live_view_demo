defmodule SpaceBirds.Behaviour.Selector do
  alias SpaceBirds.Behaviour.Node
  use Node

  @type t :: %{
    children: [Node.t]
  }

  defstruct children: []

  @impl(Node)
  def init(node, id, component, arena) do
    Enum.reduce(node.node_data.children, id, fn
      child, id when is_number(id) ->
        [Node.init(child, id, component, arena)]
      child, children ->
        {:ok, %{id: id}} = hd(children)
        [Node.init(child, id + 1, component, arena) | children]
    end)
    |> ResultEx.flatten_enum
    |> ResultEx.map(fn
      [] ->
        put_in(node.node_data.children, [])
      children ->
        node = put_in(node.node_data.children, Enum.reverse(children))
        %{id: id} = hd(children)
        Map.put(node, :id, id + 1)
    end)
  end

  @impl(Node)
  def select(node, component, arena) do
    Enum.reduce(node.node_data.children, :failure, fn
      node, :failure ->
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
      Enum.map(children, fn child -> Node.sync_running_node(child, running_node) end)
    end)
  end

end
