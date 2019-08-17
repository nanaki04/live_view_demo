defmodule SpaceBirds.Components.Collider do
  alias SpaceBirds.Components.Component
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

end
