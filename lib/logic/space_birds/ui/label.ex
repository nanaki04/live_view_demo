defmodule SpaceBirds.UI.Label do
  alias SpaceBirds.Logic.Color
  use SpaceBirds.UI.Node

  @impl(Node)
  def render(node, parent, render_data_list) do
    render_data = render_default(node, parent, render_data_list)
                  |> Map.delete(:background)
                  |> Map.put(:font_color, Color.to_hex(node.color))

    Node.render_children(node, parent, [render_data | render_data_list])
  end

end
