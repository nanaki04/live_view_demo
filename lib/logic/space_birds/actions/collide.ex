defmodule SpaceBirds.Actions.Collide do
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position

  @type t :: %{
    target: Actor.t,
    at: Position.t
  }

  defstruct target: 0,
    at: %{x: 0, y: 0}

end
