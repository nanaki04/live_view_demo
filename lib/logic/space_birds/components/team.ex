defmodule SpaceBirds.Components.Team do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.MasterData
  use Component

  @type t :: %{
    team_id: number | String.t
  }

  defstruct team_id: 0

  @spec find_team_id(Arena.t, Actor.t) :: {:some, Actor.t} | :none
  def find_team_id(arena, actor) do
    with {:ok, team} <- Components.fetch(arena.components, :team, actor)
    do
      {:some, team.component_data.team_id}
    else
      _ ->
        :none
    end
  end

  def is_ally?(team_id, actor, arena) do
    find_team_id(arena, actor)
    |> OptionEx.map(& team_id == &1)
    |> OptionEx.or_else(false)
  end

  @spec without_allies([Actor.t], Arena.t, Actor.t) :: [Actor.t]
  def without_allies(actors, arena, actor) do
    find_team_id(arena, actor)
    |> OptionEx.map(fn team_id -> Enum.filter(actors, & !is_ally?(team_id, &1, arena)) end)
    |> OptionEx.or_else(actors)
  end

  @spec filter_allies([Actor.t], Arena.t, Actor.t) :: [Actor.t]
  def filter_allies(actors, arena, actor) do
    find_team_id(arena, actor)
    |> OptionEx.map(fn team_id -> Enum.filter(actors, & is_ally?(team_id, &1, arena)) end)
    |> OptionEx.or_else([])
  end

  @spec copy_team(MasterData.t, Arena.t, Actor.t) :: MasterData.t
  def copy_team(prototype, arena, actor) do
    with {:ok, team} <- Components.fetch(arena.components, :team, actor)
    do
      {:ok, Map.put(prototype, :team, team)}
    else
      _ ->
        {:ok, prototype}
    end
  end

end
