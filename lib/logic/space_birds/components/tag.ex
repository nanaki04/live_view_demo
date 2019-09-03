defmodule SpaceBirds.Components.Tag do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  use Component

  @type tag :: String.t

  @type t :: %{
    tag: tag
  }

  defstruct tag: "default"

  @spec find_tag(Arena.t, Actor.t) :: tag
  def find_tag(arena, actor) do
    with {:ok, tag} <- Components.fetch(arena.components, :tag, actor)
    do
      tag.component_data.tag
    else
      _ ->
        "default"
    end
  end

  @spec find_actors_by_tag(Arena.t, tag | [tag]) :: {:ok, [Actor.t]} | {:error, String.t}
  def find_actors_by_tag(arena, tag) when is_list(tag) do
    Enum.reduce(tag, [], fn tag, acc ->
      acc ++ find_actors_by_tag(arena, tag)
    end)
  end

  def find_actors_by_tag(arena, tag) do
    Components.fetch(arena.components, :tag)
    |> ResultEx.map(fn tags ->
      Enum.filter(tags, fn
        {_, %{component_data: %{tag: ^tag}}} -> true
        _ -> false
      end)
      |> Enum.map(fn {actor, _} -> actor end)
    end)
  end

end
