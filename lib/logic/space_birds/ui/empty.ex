defmodule SpaceBirds.UI.Empty do
  use SpaceBirds.UI.Node

  @impl(Node)
  def render(node, parent, render_data_list) do
    render_data = render_default(node, parent, render_data_list)
                  |> Map.put(:hidden, true)

    Node.render_children(node, parent, [render_data | render_data_list])
  end

end
