defmodule SpaceBirds.Actions.FireWeapon do
  alias SpaceBirds.Logic.Position

  @type t :: %{
    target: Position.t
  }

  defstruct target: %Position{}

end
