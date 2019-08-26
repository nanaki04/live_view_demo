defmodule SpaceBirds.UI.WeaponPanel do
  alias SpaceBirds.Components.Arsenal
  use SpaceBirds.UI.Node

  @icons_per_row 3
  @max_visible_icons 5
  @icon_size %{width: 15, height: 15}

  @type t :: %{
    arsenal: Arsenal.t
  }

  defstruct arsenal: %Arsenal{}

  @impl(Node)
  def run(node, component, arena) do
    node = put_in(node.children, [])
    node = Enum.take(node.node_data.arsenal.component_data.weapons, @max_visible_icons)
           |> Enum.reduce(node, fn
             {_, %{icon: "white"}}, node ->
               icon = %Node{
                 type: "panel",
                 position: find_position(length(node.children)),
                 size: @icon_size
               }

               update_in(node.children, & [icon | &1])
             {_, %{icon: icon_path}}, node ->
               icon = %Node{
                 type: "panel",
                 texture: icon_path,
                 position: find_position(length(node.children)),
                 size: @icon_size
               }

               update_in(node.children, & [icon | &1])
           end)

    node = if node.node_data.arsenal.component_data.selected_weapon > 0 do
      selected_effect = %Node{
        type: "panel",
        position: find_position(node.node_data.arsenal.component_data.selected_weapon - 1),
        size: @icon_size,
        color: %{r: 0, g: 0, b: 0, a: 100}
      }

      update_in(node.children, & Enum.reverse([selected_effect | &1]))
    else
      node
    end

    Node.run_children(node, component, arena)
  end

  defp find_position(idx) do
    x = (@icon_size.width + 2) * rem(idx, @icons_per_row)
    y = (@icon_size.height + 2) * floor(idx / @icons_per_row)
    %{x: x, y: y}
  end

end
