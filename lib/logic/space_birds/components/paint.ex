defmodule SpaceBirds.Components.Paint do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Color
  use Component

  defstruct color: %Color{}
end
