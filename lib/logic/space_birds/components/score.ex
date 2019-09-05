defmodule SpaceBirds.Components.Score do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Logic.Actor
  use Component

  @type t :: %{
    name: String.t,
    kills: number,
    assists: number,
    deaths: number,
    damage_done: number,
    comp_stomps: number,
    dealt_damage_to: MapSet.t(Actor.t)
  }

  defstruct name: "",
    kills: 0,
    assists: 0,
    deaths: 0,
    damage_done: 0,
    comp_stomps: 0,
    dealt_damage_to: MapSet.new()

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn component ->
      {:ok, update_in(component.component_data, & Map.merge(%__MODULE__{}, &1))}
    end)
  end

  @spec log_damage(Arena.t, damage :: number, to :: Actor.t, by :: Actor.t) :: {:ok, Arena.t} | {:error, term}
  def log_damage(arena, damage, to, by) do
    map(arena, fn
      %{actor: actor} = score when actor == by ->
        score = update_in(score.component_data.dealt_damage_to, & MapSet.put(&1, to))
        {:ok, update_in(score.component_data.damage_done, &(&1 + damage))}
      score ->
        {:ok, score}
    end)
  end

  @spec log_kill(Arena.t, to :: Actor.t, by :: Actor.t) :: {:ok, Arena.t} | {:error, term}
  def log_kill(arena, to, by) do
    case Tag.find_tag(arena, to) do
      "player" ->
        map(arena, fn
          %{actor: actor} = score when actor == to ->
            {:ok, update_in(score.component_data.deaths, &(&1 + 1))}
          %{actor: actor} = score when actor == by ->
            score = update_in(score.component_data.dealt_damage_to, & MapSet.delete(&1, to))
            {:ok, update_in(score.component_data.kills, &(&1 + 1))}
          score ->
            score = if MapSet.member?(score.component_data.dealt_damage_to, to) do
              update_in(score.component_data.assists, &(&1 + 1))
            else
              score
            end
            score = update_in(score.component_data.dealt_damage_to, & MapSet.delete(&1, to))
            {:ok, score}
        end)
      "ai" ->
        map(arena, fn
          %{actor: actor} = score when actor == to ->
            {:ok, update_in(score.component_data.deaths, &(&1 + 1))}
          %{actor: actor} = score when actor == by ->
            score = update_in(score.component_data.dealt_damage_to, & MapSet.delete(&1, to))
            {:ok, update_in(score.component_data.comp_stomps, &(&1 + 1))}
          score ->
            {:ok, update_in(score.component_data.dealt_damage_to, & MapSet.delete(&1, to))}
        end)
      _ ->
        {:ok, arena}
    end
  end

  defp map(arena, handle) do
    {:ok, scores} = Components.fetch(arena.components, :score)
    Enum.reduce(scores, {:ok, arena}, fn
      {_, score}, {:ok, arena} ->
        {:ok, score} =  handle.(score)
        Arena.update_component(arena, score, fn _ -> {:ok, score} end)
      _, error ->
        error
    end)
  end

end
