defmodule SpaceBirds.UI.StatsPanel do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.UI.Gauge
  alias SpaceBirds.UI.BuffDebuffPanel
  use SpaceBirds.UI.Node

  @type t :: %{
    other_player_index: number
  }

  defstruct other_player_index: 0

  @impl(Node)
  def run(node, component, arena) do
    my_id = component.component_data.owner
    players = Enum.filter(arena.players, fn
      %{id: ^my_id} -> false
      _ -> true
    end)

    with %{id: player_id} = player <- Enum.at(players, node.node_data.other_player_index),
         {:ok, actor} <- Arena.find_player_actor(arena, player_id),
         {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, actor)
    do
      {:ok, stats} = Components.fetch(arena.components, :stats, actor)

      node = put_in(node.color, %Color{r: 10, g: 10, b: 10, a: 255})

      node = put_in(node.children, [
        %Node{
          type: "label",
          position: %Position{x: 10, y: 10},
          size: %Size{width: 400, height: 20},
          text: player.name,
          color: %Color{r: 255, g: 255, b: 255, a: 255}
        },
        #        %Node{
        #          type: "label",
        #          position: %Position{x: 10, y: 40},
        #          size: %Size{width: 400, height: 20},
        #          text: "#{stats.component_data.hp} / #{stats.component_data.max_hp}",
        #          color: %Color{r: 255, g: 255, b: 255, a: 255}
        #        },
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
          position: %Position{x: 10, y: 64},
          size: %Size{width: 100, height: 12},
          color: %Color{r: 0, g: 0, b: 0, a: 0},
          node_data: %BuffDebuffPanel{
            buff_debuff_stack: buff_debuff_stack.component_data
          }
        }

      ])

      Node.run_children(node, component, arena)
    else
      _ ->
        node = put_in(node.color, %Color{r: 0, g: 0, b: 0, a: 0})
        {:ok, put_in(node.children, [])}
    end
  end

end
