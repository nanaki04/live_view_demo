defmodule SpaceBirds.UI.Node do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Color
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Arena
  alias __MODULE__
  use SpaceBirds.Utility.MapAccess

  @type ui_node_type :: String.t

  @type render_data :: %{
    required(:type) => atom,
    required(:left) => number,
    required(:top) => number,
    required(:width) => number,
    required(:height) => number,
    required(:text) => String.t,
    required(:hidden) => boolean,
    optional(:font_color) => String.t,
    optional(:background) => String.t,
    optional(:texture) => String.t,
    optional(:opacity) => number
  }

  @type t :: %{
    type: ui_node_type,
    position: Position.t,
    world_position: Position.t,
    size: Size.t,
    color: Color.t,
    texture: String.t,
    text: String.t,
    node_data: map
  }

  defstruct type: "",
    position: %Position{},
    world_position: %Position{},
    size: %Size{},
    children: [],
    color: %Color{r: 255, g: 255, b: 255, a: 255},
    texture: "none",
    text: "",
    node_data: %{}

  @callback run(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  @callback render(t, t, [render_data]) :: [render_data]

  defmacro __using__(_opts) do
    quote do
      alias SpaceBirds.UI.Node
      use SpaceBirds.Utility.MapAccess
      @behaviour Node

      @impl(Node)
      def run(node, component, arena) do
        Node.run_children(node, component, arena)
      end

      @impl(Node)
      def render(node, parent, render_data_list) do
        render_data = render_default(node, parent, render_data_list)
        render_data_list = [render_data | render_data_list]
        Node.render_children(node, parent, render_data_list)
      end

      defp render_default(node, parent, render_data_list) do
        render_data = %{
          type: :ui,
          left: parent.world_position.x + node.position.x,
          top: parent.world_position.y + node.position.y,
          width: node.size.width,
          height: node.size.height,
          text: node.text,
          hidden: false
        }

        render_data = case node.texture do
          "none" -> render_data
          "" -> render_data
          texture -> Map.put(render_data, :texture, texture)
        end

        render_data = case node.color do
          %{a: alpha} = color when alpha < 255 -> 
            Map.put(render_data, :opacity, alpha / 255)
            |> Map.put(:background, Color.to_hex(color))
          color -> Map.put(render_data, :background, Color.to_hex(color))
        end

        case Map.fetch(node, :opacity) do
          {:ok, opacity} ->
            Map.put(render_data, :opacity, opacity / 255)
          _ ->
            render_data
        end
      end

      defoverridable [run: 3, render: 3]
    end
  end

  @spec run(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  def run(node, component, arena) do
    get_module_name(node)
    |> apply(:run, [node, component, arena])
  end

  @spec render(t, t, [render_data]) :: [render_data]
  def render(node, parent, render_data_list) do
    get_module_name(node)
    |> apply(:render, [node, parent, render_data_list])
  end

  @spec render_children(t, t, [render_data]) :: [render_data]
  def render_children(node, parent, render_data_list) do
    node = update_world_position(node, parent)
    Enum.reduce(node.children, render_data_list, & Node.render(&1, node, &2))
  end

  @spec run_children(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  def run_children(node, component, arena) do
    Enum.reduce(node.children, {:ok, []}, fn
      child, {:ok, children} ->
        Node.run(child, component, arena)
        |> ResultEx.map(fn child -> [child | children] end)
      _, error -> error
    end)
    |> ResultEx.map(&Enum.reverse/1)
    |> ResultEx.map(fn children -> put_in(node.children, children) end)
  end

  defp get_module_name(node) do
    node.type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.UI, &1)).()
  end

  defp update_world_position(node, parent) do
    put_in(node.world_position, %Position{
      x: node.position.x + parent.world_position.x,
      y: node.position.y + parent.world_position.y
    })
  end

end
