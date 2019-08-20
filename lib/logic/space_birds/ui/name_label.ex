defmodule SpaceBirds.UI.NameLabel do
  alias SpaceBirds.UI.Label
  use SpaceBirds.UI.Node

  @type t :: %{
    other_player_index: number
  }

  defstruct other_player_index: 0

  @impl(Node)
  def run(node, component, arena) do
    my_id = component.component_data.owner
    player_names = Enum.filter(arena.players, fn
      %{id: ^my_id} -> false
      _ -> true
    end)
    |> Enum.map(& &1.name)

    node = case Enum.at(player_names, node.node_data.other_player_index) do
      nil ->
        put_in(node.text, "")
      player_name ->
        put_in(node.text, player_name)
    end

    Node.run_children(node, component, arena)
  end

  @impl(Node)
  def render(node, parent, render_data_list) do
    Label.render(node, parent, render_data_list)
  end

end
