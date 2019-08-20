defmodule SpaceBirds.UI.MyNameLabel do
  alias SpaceBirds.UI.Label
  use SpaceBirds.UI.Node

  @impl(Node)
  def run(node, component, arena) do
    player_id = component.component_data.owner
    player = Enum.find(arena.players, fn
      %{id: ^player_id} -> true
      _ -> false
    end)

    node = put_in(node.text, player.name)
    Node.run_children(node, component, arena)
  end

  @impl(Node)
  def render(node, parent, render_data_list) do
    Label.render(node, parent, render_data_list)
  end

end
