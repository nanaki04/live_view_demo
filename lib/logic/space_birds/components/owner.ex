defmodule SpaceBirds.Components.Owner do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.MasterData
  use Component

  @type t :: %{
    owner: Actor.t
  }

  defstruct owner: 0

  @spec find_owner(Arena.t, Actor.t) :: {:some, Actor.t} | :none
  def find_owner(arena, actor) do
    with {:ok, owner} <- Components.fetch(arena.components, :owner, actor)
    do
      {:some, owner.component_data.owner}
    else
      _ ->
        :none
    end
  end

  @spec without_owner([Actor.t], Arena.t, Actor.t) :: [Actor.t]
  def without_owner(actors, arena, actor) do
    find_owner(arena, actor)
    |> OptionEx.map(fn owner -> Enum.filter(actors, & owner != &1) end)
    |> OptionEx.or_else(actors)
  end

  @spec copy_owner(MasterData.t, Arena.t, Actor.t) :: MasterData.t
  def copy_owner(prototype, arena, actor) do
    with {:ok, owner} <- Components.fetch(arena.components, :owner, actor)
    do
      {:ok, Map.put(prototype, :owner, owner)}
    else
      _ ->
        {:ok, prototype}
    end
  end

end
