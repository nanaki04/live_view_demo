defmodule SpaceBirds.Components.Texture do
  alias SpaceBirds.Components.Component
  use Component

  @type t :: %{
    required(:path) => String.t,
    required(:opacity) => number,
    optional(:blit) => String.t
  }

  defstruct path: "",
    opacity: 255
end
