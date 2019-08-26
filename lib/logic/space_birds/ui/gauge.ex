defmodule SpaceBirds.UI.Gauge do
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Position
  use SpaceBirds.UI.Node

  @type t :: %{
    gauge_color: Color.t | Color.gradient,
    max_value: number,
    current_value: number,
    border: number
  }

  defstruct gauge_color: %Color{},
    max_value: 1,
    min_value: 0,
    current_value: 0,
    border: 3

  @impl(Node)
  def run(node, component, arena) do
    gauge_size = %Size{
      width: calculate_gauge_size(node.size.width, node.node_data.border, node.node_data.current_value, node.node_data.max_value),
      height: node.size.height - 2 * node.node_data.border
    }
    gauge_color = calculate_gauge_color(node.node_data.gauge_color, node.node_data.current_value, node.node_data.max_value)
    node = draw(node, gauge_size, gauge_color)
    Node.run_children(node, component, arena)
  end

  @spec calculate_gauge_color(Color.t | Color.gradient, current_value :: number, max_value :: number) :: Color.t
  def calculate_gauge_color(%{r: _, g: _, b: _} = color, _current_value, _max_value) do
    color
  end

  def calculate_gauge_color(gauge_color, 0, _max_value) do
    Color.get_color_on_gradient(gauge_color, 0)
  end

  def calculate_gauge_color(gauge_color, current_value, max_value) do
    Color.get_color_on_gradient(gauge_color, current_value / max_value)
  end

  @spec calculate_gauge_size(max_size :: number, border :: number, current_value :: number, max_value :: number) :: number
  def calculate_gauge_size(max_size, border, current_value, max_value) do
    round(((max_size - 2 * border) / max_value) * current_value)
  end

  defp calculate_gauge_position(node, gauge_size) do
    x = node.node_data.border
    y = node.size.height - gauge_size.height - node.node_data.border
    %Position{x: x, y: y}
  end

  @spec draw(Node.t, Size.t, Color.t) :: Node.t
  def draw(node, gauge_size, gauge_color) do
    put_in(node.children, [
      %Node{
        type: "panel",
        position: %Position{x: 0, y: 0},
        size: node.size,
        color: %Color{r: 0, g: 0, b: 0, a: 255}
      },
      %Node{
        type: "panel",
        position: calculate_gauge_position(node, gauge_size),
        size: gauge_size,
        color: gauge_color
      }
    ])
  end

end
