defmodule SpaceBirds.Components.LifeBinder do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Defeatable
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Logic.Actor
  use Component

  @type t :: %{
    target: Actor.t
  }

  defstruct target: 0

  @impl(Component)
  def run(component, arena) do
    with {:ok, readonly_stats} <- Stats.get_readonly(arena, component.component_data.target),
         hp when hp <= 0 <- readonly_stats.component_data.hp,
         {:ok, defeatable} <- Components.fetch(arena.components, :defeatable, component.actor)
    do
      Defeatable.remove(defeatable, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

end
