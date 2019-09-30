defmodule SpaceBirds.Components.Name do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  use Component

  @type t :: %{
    name: String.t
  }

  defstruct name: "UFO"

  @spec find_name(Arena.t, Actor.t) :: {:some, String.t} | :none
  def find_name(arena, actor) do
    with {:ok, name} <- Components.fetch(arena.components, :name, actor)
    do
      {:some, name.component_data.name}
    else
      _ ->
        :none
    end
  end

end
