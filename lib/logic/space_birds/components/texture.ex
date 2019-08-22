defmodule SpaceBirds.Components.Texture do
  alias SpaceBirds.Components.Component
  use Component

  @type t :: %{
    path: String.t,
    opacity: number
  }

  defstruct path: "",
    opacity: 255
end
