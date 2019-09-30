defmodule SpaceBirds.UI.AiStatsPanel do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Components.Name
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.UI.StatsPanel
  use SpaceBirds.UI.Node

  @impl(Node)
  def run(node, component, arena) do
    with [_ | _] = ai_actors <- Tag.find_by_tag_without_owner(arena, "ai", component.actor),
         {:ok, transforms} <- Enum.map(ai_actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, target} <- Transform.find_closest_target(transform, transforms),
         {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, target.actor),
         {:ok, stats} <- Components.fetch(arena.components, :stats, target.actor),
         {:some, name} <- Name.find_name(arena, target.actor)
    do
      StatsPanel.build_nodes(node, name, stats, buff_debuff_stack, component, arena)
    else
      _ ->
        node = put_in(node.color, %Color{r: 0, g: 0, b: 0, a: 0})
        {:ok, put_in(node.children, [])}
    end
  end

end
