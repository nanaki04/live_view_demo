defmodule SpaceBirds.Components.VisualEffectStack do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  alias SpaceBirds.Logic.Actor
  use Component

  @type t :: %{
    effects: %{MasterData.visual_effect_type => Actor.t},
  }

  @spec add_visual_effect(Component.t, MasterData.visual_effect_type, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def add_visual_effect(component, visual_effect_type, arena) do
    {:ok, arena} = case Map.fetch(component.component_data.effects, visual_effect_type) do
      {:ok, old_effect} ->
        Arena.remove_actor(arena, old_effect)
      _ ->
        {:ok, arena}
    end

    {:ok, visual_effect} = MasterData.get_visual_effect(visual_effect_type)
    actor_id = arena.last_actor_id + 1
    {:ok, arena} = Arena.add_actor(arena, visual_effect)
    component = put_in(component.component_data.effects[visual_effect_type], actor_id)

    Arena.update_component(arena, component, fn _ -> {:ok, component} end)
  end

  @spec remove_visual_effect(Component.t, MasterData.visual_effect_type, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def remove_visual_effect(component, visual_effect_type, arena) do
    case Map.fetch(component.component_data.effects, visual_effect_type) do
      {:ok, effect_id} ->
        component = update_in(component.component_data.effects, & Map.delete(&1, visual_effect_type))
        {:ok, arena} = Arena.remove_actor(arena, effect_id)
        Arena.update_component(arena, component, fn _ -> {:ok, component} end)
      _ ->
        {:ok, arena}
    end
  end

  @spec find(Component.t, MasterData.visual_effect_type) :: {:some, Actor.t} | :none
  def find(component, visual_effect_type) do
    case Map.fetch(component.component_data.effects, visual_effect_type) do
      {:ok, effect_id} -> {:some, effect_id}
      _ -> :none
    end
  end

  @spec remove_all_visual_effects(Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def remove_all_visual_effects(component, arena) do
    Enum.reduce(component.component_data.effects, arena, fn
      {_, effect}, {:ok, arena} ->
        Arena.remove_actor(arena, effect)
      _, error ->
        error
    end)
  end

  @spec owns?(Component.t, Actor.t | MasterData.visual_effect_type) :: boolean
  def owns?(component, actor) when is_number(actor) do
    Enum.any?(component.component_data.effects, fn
      {_, ^actor} -> true
      _ -> false
    end)
  end

  def owns?(component, visual_effect_type) when is_binary(visual_effect_type) do
    Enum.any?(component.component_data.effects, fn
      {^visual_effect_type, _} -> true
      _ -> false
    end)
  end

end
