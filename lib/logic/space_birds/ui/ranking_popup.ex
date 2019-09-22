defmodule SpaceBirds.UI.RankingPopup do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Components.Components
  alias SpaceBirds.UI.Button
  alias SpaceBirds.UI.Label
  use SpaceBirds.UI.Node

  @type t :: %{
    is_open?: boolean
  }

  defstruct is_open?: false

  @impl(Node)
  def run(node, component, arena) do
    clicks = Button.find_click_events("ranking_popup", component, arena)

    node = if length(clicks) > 0, do: update_in(node.node_data.is_open?, & not &1), else: node
    node = if arena.time_left <= 0, do: put_in(node.node_data.is_open?, true), else: node

    if node.node_data.is_open? do
      {:ok, scores} = Components.fetch(arena.components, :score)
      scores = Enum.map(scores, fn {_, %{component_data: score}} -> score end)
               |> Enum.sort(fn
                 %{kills: kills1}, %{kills: kills2} when kills1 > kills2 -> true
                 %{kills: kills1}, %{kills: kills2} when kills1 < kills2 -> false
                 %{deaths: deaths1}, %{deaths: deaths2} when deaths1 < deaths2 -> true
                 %{deaths: deaths1}, %{deaths: deaths2} when deaths1 > deaths2 -> false
                 %{assists: assists1}, %{assists: assists2} when assists1 < assists2 -> true
                 %{assists: assists1}, %{assists: assists2} when assists1 > assists2 -> false
                 %{damage_done: damage_done1}, %{damage_done: damage_done2} when damage_done1 > damage_done2 -> true
                 %{damage_done: damage_done1}, %{damage_done: damage_done2} when damage_done1 < damage_done2 -> false
                 %{comp_stomps: comp_stomps1}, %{comp_stomps: comp_stomps2} when comp_stomps1 > comp_stomps2 -> true
                 %{comp_stomps: comp_stomps1}, %{comp_stomps: comp_stomps2} when comp_stomps1 < comp_stomps2 -> false
                 _, _ -> true
              end)

      header = %Node{
        type: "panel",
        position: %Position{x: 10, y: 10},
        size: %Size{width: 580, height: 10},
        color: %Color{r: 150, g: 0, b: 0, a: 15},
        children: [
          Label.new("Rank", 0, 0, 60, 20, Color.white()),
          Label.new("Name", 60, 0, 140, 20, Color.white()),
          Label.new("Kills", 200, 0, 60, 20, Color.white()),
          Label.new("Deaths", 260, 0, 60, 20, Color.white()),
          Label.new("Assists", 320, 0, 60, 20, Color.white()),
          Label.new("Damage", 380, 0, 140, 20, Color.white()),
          Label.new("AI kills", 520, 0, 60, 20, Color.white())
        ]
      }

      children = Enum.with_index(scores)
                 |> Enum.map(fn {score, index} ->
                   %Node{
                     type: "panel",
                     position: %Position{x: 10, y: 40 + index * 22},
                     size: %Size{width: 580, height: 20},
                     color: %Color{r: 0, g: 0, b: 0, a: 0},
                     children: [
                       Label.new("#{index + 1}", 0, 0, 60, 20, Color.white()),
                       Label.new(score.name, 60, 0, 140, 20, Color.white()),
                       Label.new("#{score.kills}", 200, 0, 60, 20, Color.white()),
                       Label.new("#{score.deaths}", 260, 0, 60, 20, Color.white()),
                       Label.new("#{score.assists}", 320, 0, 60, 20, Color.white()),
                       Label.new("#{round(score.damage_done)}", 380, 0, 140, 20, Color.white()),
                       Label.new("#{score.comp_stomps}", 520, 0, 60, 20, Color.white())
                     ]
                   }
                 end)

      {:ok, put_in(node.children, [header | children])}
    else
      put_in(node.children, [])
      {:ok, node}
    end
  end

  @impl(Node)
  def render(%{node_data: %{is_open?: false}}, _parent, render_data_list) do
    render_data_list
  end

  def render(node, parent, render_data_list) do
    render_data = render_default(node, parent, render_data_list)
    render_data_list = [render_data | render_data_list]
    Node.render_children(node, parent, render_data_list)
  end

end
