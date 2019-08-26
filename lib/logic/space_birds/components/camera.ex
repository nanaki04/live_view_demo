defmodule SpaceBirds.Components.Camera do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Ui
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  use Component

  @background_actor 1
  @ui_width 120
  @ui_height 100

  @type t :: %{
    owner: Players.player_id,
    render_data: term # TODO
  }

  defstruct owner: 0,
    render_data: []

  @impl(Component)
  def run(component, arena) do
    with {:ok, camera_transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, transforms} <- Components.fetch(arena.components, :transform),
         {:ok, player} <- Arena.find_player(arena, component.component_data.owner),
         {:ok, background} <- Components.fetch(arena.components, :transform, @background_actor)
    do
      camera_transform = cap_camera_position(camera_transform, player, background)
      {:ok, arena} = Arena.update_component(arena, camera_transform, fn _ -> {:ok, camera_transform} end)

      transforms = sort_by_layer(transforms)

      render_data = [render_grid(player) | render_ui(component, arena)]
      Enum.reduce(transforms, render_data, fn {actor, transform}, render_data ->
        %{type: :transform}
        |> parse_transform(transform, camera_transform, player)
        |> (fn render_data ->
          Components.fetch(arena.components, :paint, actor)
          |> ResultEx.map(fn paint -> parse_color(render_data, paint) end)
          |> ResultEx.or_else(render_data)
        end).()
        |> (fn render_data ->
          Components.fetch(arena.components, :texture, actor)
          |> ResultEx.map(fn texture -> parse_texture(render_data, texture) end)
          |> ResultEx.or_else(render_data)
        end).()
        |> (fn
          nodes when is_list(nodes) -> nodes ++ render_data
          node -> [node | render_data]
        end).()
      end)
      |> (fn render_data ->
        Arena.update_component(arena, component, fn _ ->
          {
            :ok,
            put_in(component.component_data.render_data, Enum.reverse(render_data))
          }
        end)
      end).()
    else
      # TODO display error somewhere
      _ -> Arena.update_component(arena, component, fn _ -> {:ok, put_in(component.component_data.render_data, [])} end)
    end
  end

  defp render_grid(%{resolution: {res_x, res_y}}) do
    %{
      type: :grid,
      columns: ceil((res_x - @ui_width) / 50),
      rows: ceil((res_y - @ui_height) / 50),
      width: 50,
      height: 50
    }
  end

  defp render_ui(component, arena) do
    with {:ok, ui_components} <- Components.fetch(arena.components, :ui),
         {_, %{} = ui} <- Enum.find(ui_components, fn {_, ui} -> ui.component_data.owner == component.component_data.owner end) 
    do
      Ui.render(ui)
    else
      _ -> []
    end
  end

  defp parse_transform(render_data, %{component_data: component_data}, %{component_data: %{position: cam_pos}}, player) do
    %{x: x, y: y} = component_data.position
    %{width: width, height: height} = component_data.size
    rotation = component_data.rotation
    {res_x, res_y} = player.resolution

    render_data
    |> Map.put(:left, x - width / 2 - cam_pos.x + (res_x - @ui_width) / 2)
    |> Map.put(:top, y - height / 2 - cam_pos.y + (res_y - @ui_height) / 2)
    |> Map.put(:width, width)
    |> Map.put(:height, height)
    |> Map.put(:rotation, rotation)
  end

  defp parse_texture(render_data, %{component_data: %{path: path, opacity: opacity} = component_data}) do
    render_data = render_data
                  |> Map.put(:texture, path)
                  |> Map.put(:opacity, opacity / 255)

    case Map.fetch(component_data, :blit) do
      {:ok, blit} ->
        blit_data = render_data
                    |> Map.put(:texture, blit)
                    |> Map.put(:opacity, 0)
        [render_data, blit_data]
      _ ->
        render_data
    end
  end

  defp parse_color(render_data, %{component_data: %{color: color}}) do
    render_data
    |> Map.put(:background, Color.to_hex(color))
    |> Map.put(:opacity, Color.to_opacity(color))
  end

  defp cap_camera_position(transform, %{resolution: {res_x, res_y}}, %{component_data: %{size: field_size}}) do
    min_x = -field_size.width / 2 + (res_x - @ui_width) / 2
    max_x = field_size.width / 2 - (res_x - @ui_width) / 2
    min_y = -field_size.height / 2 + (res_y - @ui_height) / 2
    max_y = field_size.height / 2 - (res_y - @ui_height) / 2

    update_in(transform.component_data.position, fn position ->
      x = position.x
          |> max(min_x)
          |> min(max_x)

      y = position.y
          |> max(min_y)
          |> min(max_y)

      %{x: x, y: y}
    end)
  end

  defp sort_by_layer(transforms) do
    Enum.sort(transforms, fn
      {_, %{component_data: %{layer: "background"}}}, _ -> true
      _, {_, %{component_data: %{layer: "background"}}} -> false
      {_, %{component_data: %{layer: "lower"}}}, _ -> true
      _, {_, %{component_data: %{layer: "lower"}}} -> false
      {_, %{component_data: %{layer: "ui"}}}, _ -> false
      _, {_, %{component_data: %{layer: "ui"}}} -> true
      {_, %{component_data: %{layer: "upper"}}}, _ -> false
      _, {_, %{component_data: %{layer: "upper"}}} -> true
      _, _ -> true
    end)
  end
end
