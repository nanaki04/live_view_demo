defmodule SpaceBirds.Components.Follow do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  use Component

  @type t :: %{
    target: SpaceBirds.Logic.Actor.t
  }

  defstruct target: 0

  @impl(Component)
  def run(component, arena) do
    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:ok, target_transform} <- Components.fetch(arena.components, :transform, component.component_data.target)
    do
      # TODO lerp
      Arena.update_component(arena, transform, fn transform ->
        {:ok, put_in(transform.component_data.position, target_transform.component_data.position)}
      end)
    else
      _ -> {:ok, arena}
    end
  end

end
