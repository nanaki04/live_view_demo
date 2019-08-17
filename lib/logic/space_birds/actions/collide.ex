defmodule SpaceBirds.Actions.Collide do
  alias SpaceBirds.Logic.Actor

  @type t :: %{
    actor: Actor.t,
    target: Actor.t
  }

  defstruct actor: 0,
    target: 0

end
