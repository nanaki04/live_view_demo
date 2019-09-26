defmodule SpaceBirds.UI.MyStatsPanel do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Components.Components
  alias SpaceBirds.UI.Gauge
  alias SpaceBirds.UI.BuffDebuffPanel
  use SpaceBirds.UI.Node

  @impl(Node)
  def run(node, component, arena) do
    player_id = component.component_data.owner
    player = Enum.find(arena.players, fn
      %{id: ^player_id} -> true
      _ -> false
    end)

    build(node, component, player, arena)
  end

  defp build(node, _component, nil, _arena) do
    {:ok, node}
  end

  defp build(node, component, player, arena) do
    {:ok, stats} = Components.fetch(arena.components, :stats, component.actor)
    {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, component.actor)

    node = put_in(node.children, [
      %Node{
        type: "label",
        position: %Position{x: 10, y: 10},
        size: %Size{width: 400, height: 20},
        text: player.name,
        color: %Color{r: 255, g: 255, b: 255, a: 255}
      },
      %Node{
        type: "gauge",
        position: %Position{x: 10, y: 40},
        size: %Size{width: 100, height: 8},
        node_data: %Gauge{
          gauge_color: Color.new_gradient(%{r: 0, g: 0, b: 100, a: 255}, %{r: 0, g: 0, b: 255, a: 255}),
          max_value: stats.component_data.max_shield,
          current_value: stats.component_data.shield,
          border: 1
        }
      },
      %Node{
        type: "gauge",
        position: %Position{x: 10, y: 48},
        size: %Size{width: 100, height: 8},
        node_data: %Gauge{
          gauge_color: Color.new_gradient(%{r: 255, g: 100, b: 0, a: 255}, %{r: 0, g: 255, b: 100, a: 255}),
          max_value: stats.component_data.max_hp,
          current_value: stats.component_data.hp,
          border: 1
        }
      },
      %Node{
        type: "gauge",
        position: %Position{x: 10, y: 56},
        size: %Size{width: 100, height: 6},
        node_data: %Gauge{
          gauge_color: Color.new_gradient(%{r: 100, g: 0, b: 100, a: 255}, %{r: 150, g: 0, b: 150, a: 255}),
          max_value: 100,
          current_value: stats.component_data.energy,
          border: 2
        }
      },
      %Node{
        type: "buff_debuff_panel",
        position: %Position{x: 10, y: 74},
        size: %Size{width: 100, height: 12},
        color: %Color{r: 0, g: 0, b: 0, a: 0},
        node_data: %BuffDebuffPanel{
          buff_debuff_stack: buff_debuff_stack.component_data
        }
      }
    ])

    Node.run_children(node, component, arena)
  end

end
