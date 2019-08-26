defmodule SpaceBirds.UI.VerticalGauge do
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.UI.Gauge
  use SpaceBirds.UI.Node

  @type t :: Gauge.t

  @impl(Node)
  def run(node, component, arena) do
    gauge_size = %Size{
      width: node.size.width - 2 * node.node_data.border,
      height: Gauge.calculate_gauge_size(node.size.height, node.node_data.border, node.node_data.current_value, node.node_data.max_value)
    }
    gauge_color = Gauge.calculate_gauge_color(node.node_data.gauge_color, node.node_data.current_value, node.node_data.max_value)
    node = Gauge.draw(node, gauge_size, gauge_color)
    Node.run_children(node, component, arena)
  end

end
