defmodule SpaceBirds.Components.Tag do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  use Component

  @type t :: %{
    tag: String.t
  }

  defstruct tag: "default"

  def find_tag(arena, actor) do
    with {:ok, tag} <- Components.fetch(arena.components, :tag, actor)
    do
      tag.component_data.tag
    else
      _ ->
        "default"
    end
  end

end
