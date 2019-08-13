defmodule SpaceBirds.Components.Transform do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Rotation
  alias SpaceBirds.Logic.Size
  use Component

  @type t :: %{
    position: Position.t,
    rotation: Rotation.t,
    size: Size.t
  }

  defstruct position: %Position{},
    rotation: 0,
    size: %Size{}

end
