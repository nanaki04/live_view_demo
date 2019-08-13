defmodule SpaceBirds.Components.Camera do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  use Component

  @type t :: %{
    owner: Players.player_id,
    render_data: String.t
  }

  defstruct owner: 0,
    render_data: []

  @impl(Component)
  def run(component, arena) do
    with {:ok, camera_transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, transforms} <- Components.fetch(arena.components, :transform),
         {:ok, player} <- Arena.find_player(arena, component.component_data.owner)
    do
      Enum.reduce(transforms, [render_grid(player)], fn {actor, transform}, render_data ->
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
        |> (&[&1 | render_data]).()
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
      columns: round(res_x / 100),
      rows: round(res_y / 100),
      width: 100,
      height: 100
    }
  end

  defp parse_transform(render_data, %{component_data: component_data}, %{component_data: %{position: cam_pos}}, player) do
    %{x: x, y: y} = component_data.position
    %{width: width, height: height} = component_data.size
    rotation = component_data.rotation
    {res_x, res_y} = player.resolution

    render_data
    |> Map.put(:left, x - width / 2 - cam_pos.x + res_x / 2)
    |> Map.put(:top, y - height / 2 - cam_pos.y + res_y / 2)
    |> Map.put(:width, width)
    |> Map.put(:height, height)
    |> Map.put(:rotation, rotation)
  end

  defp parse_texture(render_data, %{component_data: %{path: path}}) do
    render_data
    |> Map.put(:texture, path)
  end

  defp parse_color(render_data, %{component_data: %{color: color}}) do
    render_data
    |> Map.put(:background, Color.to_hex(color))
  end
end
