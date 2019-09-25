defmodule SpaceBirds.Components.Collider do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Logic.Actor
  use Component

  @type layer :: String.t

  @type t :: %{
    layer: layer,
    owner: Actor.t,
    collides_with: [layer]
  }

  defstruct layer: "default",
    owner: 0,
    collides_with: []

  @spec without_owner([Actor.t], Arena.t, Actor.t) :: [Actor.t]
  def without_owner(actors, arena, actor) do
    with {:ok, collider} <- Components.fetch(arena.components, :collider, actor)
    do
      Enum.filter(actors, & collider.component_data.owner != &1)
    else
      _ ->
        actors
    end
  end
 

end
