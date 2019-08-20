defmodule SpaceBirds.Components.Ui do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  alias SpaceBirds.UI.Node
  use Component

  @type t :: %{
    owner: Players.player_id,
    root: Node.t
  }

  defstruct owner: 0,
    root: %Node{}

  @impl(Component)
  def run(component, arena) do
    {:ok, children} = Enum.map(component.component_data.root.children, & Node.run(&1, component, arena))
                      |> ResultEx.flatten_enum

    Arena.update_component(arena, component, fn component ->
      {:ok, put_in(component.component_data.root.children, children)}
    end)
  end

  @spec render(Component.t) :: [Node.render_data]
  def render(component) do
    Node.render(component.component_data.root, %Node{}, [])
  end

end
