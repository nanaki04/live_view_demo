defmodule SpaceBirds.UI.BuffDebuffPanel do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.Components.BuffDebuffStack
  use SpaceBirds.UI.Node

  @max_visible_icons 8

  @type t :: %{
    buff_debuff_stack: BuffDebuffStack.t
  }

  defstruct buff_debuff_stack: %BuffDebuffStack{}

  @impl(Node)
  def run(node, component, arena) do
    node = put_in(node.children, [])
    node = Enum.take(node.node_data.buff_debuff_stack.buff_debuffs, @max_visible_icons)
           |> Enum.reduce(node, fn
             {:last_id, _}, node ->
               node
             {_, %{icon_path: "none"}}, node ->
               node
             {_, %{icon_path: ""}}, node ->
               node
             {_, %{icon_path: "white"} = buff_debuff}, node ->
               icon_count = length(node.children)
               icon = %Node{
                 type: "panel",
                 position: %Position{x: icon_count * 12.5, y: 0},
                 size: %Size{width: 12, height: 12}
               }
               icon = flicker(buff_debuff, icon)

               update_in(node.children, & [icon | &1])
             {_, %{icon_path: icon_path} = buff_debuff}, node ->
               icon_count = length(node.children)
               icon = %Node{
                 type: "panel",
                 texture: icon_path,
                 position: %Position{x: icon_count * 12.5, y: 0},
                 size: %Size{width: 12, height: 12}
               }
               icon = flicker(buff_debuff, icon)

               update_in(node.children, & [icon | &1])
           end)

    Node.run_children(node, component, arena)
  end

  defp flicker(buff_debuff, icon) do
    progress = (buff_debuff.time - buff_debuff.time_remaining) / buff_debuff.time
    progress = max(0, 3 * progress - 2)
    progress = round(ProgressOverTime.inverse_sine_curve(%{from: 0, to: 6}, progress))
    visible = rem(progress, 2) == 0
    color = if visible, do: %Color{r: 255, g: 255, b: 255, a: 255}, else: %Color{r: 0, g: 0, b: 0, a: 0}
    Map.put(icon, :color, color)
  end

end
