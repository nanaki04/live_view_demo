defmodule SpaceBirds.Components.Tag do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Collider
  alias SpaceBirds.Components.Owner
  alias SpaceBirds.Components.Team
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

  @spec find_actors_by_tag(Arena.t, tag | [tag], Actor.t) :: {:ok, [Actor.t]} | {:error, String.t}
  def find_actors_by_tag(arena, tag, actor) when is_list(tag) do
    Enum.reduce(tag, {:ok, []}, fn
      tag, {:ok, acc} ->
        find_actors_by_tag(arena, tag, actor)
        |> ResultEx.map(fn actors -> Enum.uniq(acc ++ actors) end)
      _, error ->
        error
    end)
  end

  def find_actors_by_tag(arena, "ally_" <> tag, actor) do
    {:ok, actors} = find_actors_by_tag(arena, tag, actor)
    {:ok, Team.filter_allies(actors, arena, actor)}
  end

  def find_actors_by_tag(arena, tag, _actor) do
    Components.fetch(arena.components, :tag)
    |> ResultEx.map(fn tags ->
      Enum.filter(tags, fn
        {_, %{component_data: %{tag: ^tag}}} -> true
        _ -> false
      end)
      |> Enum.map(fn {actor, _} -> actor end)
    end)
  end

  def find_by_tag_without_self(arena, tag, actor) do
    {:ok, actors} = find_actors_by_tag(arena, tag, actor)

    actors
    |> Enum.filter(& actor != &1)
  end

  def find_by_tag_without_owner(arena, tag, actor) do
    {:ok, actors} = find_actors_by_tag(arena, tag, actor)

    actors
    |> Owner.without_owner(arena, actor)
    |> Collider.without_owner(arena, actor)
    |> Team.without_allies(arena, actor)
    |> Enum.filter(& actor != &1)
  end

end
