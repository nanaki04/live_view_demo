defmodule SpaceBirds.UI.Gauge do
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Position
  use SpaceBirds.UI.Node

  @type t :: %{
    gauge_color: Color.t | Color.gradient,
    max_value: number,
    current_value: number
  }

  defstruct gauge_color: %Color{},
    max_value: 1,
    min_value: 0,
    border: 3

  @impl(Node)
  def run(node, component, arena) do
    gauge_size = %Size{
      width: round(((node.size.width - 2 * node.node_data.border) / node.node_data.max_value) * node.node_data.min_value),
      height: node.size.height - 2 * node.node_data.border
    }

    gauge_color = case {node.node_data.gauge_color, node.node_data.min_value} do
      {%{from: _, to: _} = gradient, 0} ->
        Color.get_color_on_gradient(gradient, 0)
      {%{from: _, to: _} = gradient, min_value} ->
        Color.get_color_on_gradient(gradient, min_value / node.node_data.max_value)
      {color, _} ->
        color
    end

    node = put_in(node.children, [
      %Node{
        type: "panel",
        position: %Position{x: 0, y: 0},
        size: node.size,
        color: %Color{r: 0, g: 0, b: 0, a: 255}
      },
      %Node{
        type: "panel",
        position: %Position{x: node.node_data.border, y: node.node_data.border},
        size: gauge_size,
        color: gauge_color
      }
    ])

    Node.run_children(node, component, arena)
  end

end
