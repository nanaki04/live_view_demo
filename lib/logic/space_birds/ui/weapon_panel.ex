defmodule SpaceBirds.UI.WeaponPanel do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.UI.Gauge
  alias SpaceBirds.Weapons.Weapon
  use SpaceBirds.UI.Node

  @icons_per_row 3
  @max_visible_icons 5
  @icon_size %{width: 50, height: 50}

  @type t :: %{
  }

  @impl(Node)
  def run(node, component, arena) do
    {:ok, arsenal} = Components.fetch(arena.components, :arsenal, component.actor)
    main_weapon = arsenal.component_data.weapons[0]

    node = put_in(node.children, [])
    node = Enum.take(arsenal.component_data.weapons, @max_visible_icons)
           |> Enum.reduce(node, fn
             {0, _}, node ->
               node
             {_, %{icon: "white"} = weapon}, node ->
               position = find_position(round(length(node.children) / 2))

               icon = %Node{
                 type: "panel",
                 position: position,
                 size: @icon_size
               }

               cooldownGauge = %Node{
                 type: "vertical_gauge",
                 position: position,
                 size: @icon_size,
                 node_data: %Gauge{
                   gauge_color: Color.new_gradient(%{r: 0, g: 0, b: 0, a: 200}, %{r: 0, g: 0, b: 0, a: 100}),
                   max_value: 1,
                   min_value: 0,
                   current_value: 1 - Weapon.cooldown_progress(weapon),
                   border: 0,
                   background_color: %Color{r: 0, g: 0, b: 0, a: 0}
                 }
               }

               update_in(node.children, & [cooldownGauge | [icon | &1]])
             {_, %{icon: icon_path} = weapon}, node ->
               position = find_position(round(length(node.children) / 2))

               icon = %Node{
                 type: "panel",
                 texture: icon_path,
                 position: position,
                 size: @icon_size
               }

               cooldownGauge = %Node{
                 type: "vertical_gauge",
                 position: position,
                 size: @icon_size,
                 node_data: %Gauge{
                   gauge_color: Color.new_gradient(%{r: 0, g: 0, b: 0, a: 200}, %{r: 0, g: 0, b: 0, a: 100}),
                   max_value: 1,
                   min_value: 0,
                   current_value: 1 - Weapon.cooldown_progress(weapon),
                   border: 0,
                   background_color: %Color{r: 0, g: 0, b: 0, a: 0}
                 }
               }

               update_in(node.children, & [cooldownGauge | [icon | &1]])
           end)

    main_weapon_cooldown_gauge = %Node{
      type: "vertical_gauge",
      position: %Position{x: 0, y: 0},
      size: %Size{width: 8, height: 50},
      node_data: %Gauge{
        gauge_color: Color.new_gradient(%{r: 255, g: 0, b: 0, a: 255}, %{r: 0, g: 255, b: 0, a: 255}),
        max_value: 1,
        min_value: 0,
        current_value: Weapon.cooldown_progress(main_weapon),
        border: 1
      }
    }

    node = update_in(node.children, & [main_weapon_cooldown_gauge | &1])

    node = if arsenal.component_data.selected_weapon > 0 do
      selected_effect = %Node{
        type: "panel",
        position: find_position(arsenal.component_data.selected_weapon - 1),
        size: @icon_size,
        color: %{r: 0, g: 0, b: 0, a: 100}
      }

      update_in(node.children, & [selected_effect | &1])
    else
      node
    end

    node = update_in(node.children, &Enum.reverse/1)

    Node.run_children(node, component, arena)
  end

  defp find_position(idx) do
    x = (@icon_size.width + 2) * rem(idx, @icons_per_row) + 25
    y = (@icon_size.height + 2) * floor(idx / @icons_per_row)
    %{x: x, y: y}
  end

end
