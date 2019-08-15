defmodule SpaceBirds.Components.Lifetime do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Arena
  use Component

  @type t :: %{
    milliseconds: number
  }

  defstruct milliseconds: 0

  @impl(Component)
  def run(component, arena) do
    component = update_in(component.component_data.milliseconds, & &1 - arena.delta_time * 1000)

    if component.component_data.milliseconds <= 0 do
      Arena.remove_actor(arena, component.actor)
    else
      Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    end
  end

end
