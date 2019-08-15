defmodule SpaceBirds.Components.Destination do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Components.Component
  use Component

  @type target :: :none
    | {:some, Position.t}
    | {:some, Actor.t}

  @type t :: %{
    target: target
  }

  defstruct target: :none

end
