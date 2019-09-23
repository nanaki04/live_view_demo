defmodule SpaceBirds.Components.Defeatable do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Components.Lifetime
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Components.VisualEffectStack
  alias SpaceBirds.MasterData
  use Component

  @type spawn_item :: %{
    path: String.t,
    weight: number
  }

  @type t :: %{
    spawn_on_death: String.t | [spawn_item]
  }

  defstruct spawn_on_death: "none"

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn component ->
      component = update_in(component.component_data, & Map.merge(%__MODULE__{}, &1))
      {:ok, component}
    end)
  end

  @impl(Component)
  def run(component, arena) do
    with {:ok, stats} <- Components.fetch(arena.components, :stats, component.actor),
         hull when hull <= 0 <- stats.component_data.hp
    do
      {:ok, visual_effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
      {:ok, arena} = VisualEffectStack.remove_all_visual_effects(visual_effect_stack, arena)
      {:ok, arena} = Arena.remove_component(arena, :movement_controller, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :movement, component.actor)
      {:ok, arena} = Arena.update_component(arena, :arsenal, component.actor, &{:ok, put_in(&1.component_data.enabled, false)})
      {:ok, arena} = Arena.remove_component(arena, :collider, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :behaviour, component.actor)
      {:ok, arena} = Arena.remove_component(arena, component)
      {:ok, arena} = Arena.update_component(arena, :animation_player, component.actor, fn animation_player ->
        AnimationPlayer.play_animation(animation_player, "fade")
      end)

      {:ok, arena} = if Tag.find_tag(arena, component.actor) == "ai" || Tag.find_tag(arena, component.actor) == "destructable" do
        Arena.add_component(arena, %Component{
          actor: component.actor,
          type: :lifetime,
          component_data: %Lifetime{
            milliseconds: 1000
          }
        })
      else
        {:ok, arena}
      end

      {:ok, arena} = Arena.update_component(arena, :stats, component.actor, fn stats ->
        Stats.deactivate(stats)
      end)

      spawn_on_death(component, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  defp spawn_on_death(component, arena) do
    with {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor)
    do
      position = transform.component_data.position
      spawn_item(component.component_data.spawn_on_death, position, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  defp spawn_item("none", _, arena) do
    {:ok, arena}
  end

  defp spawn_item(item, position, arena) when is_list(item) do
    total_weight = Enum.reduce(item, 0, fn %{weight: weight}, total_weight -> total_weight + weight end)
    roll = :rand.uniform(total_weight)

    {{:some, item}, _} = Enum.reduce(item, {:none, 0}, fn
      _, {{:some, item}, bar} ->
        {{:some, item}, bar}
      %{path: item, weight: weight}, {:none, bar} ->
        bar = bar + weight
        if roll <= bar, do: {{:some, item}, bar}, else: {:none, bar}
    end)

    spawn_item(item, position, arena)
  end

  defp spawn_item(path, position, arena) do
    with prototype_id <- arena.last_actor_id + 1,
         {:ok, prototype} <- MasterData.get_prototype(path, prototype_id)
    do
      prototype = put_in(prototype.transform.component_data.position, position)
      Arena.add_actor(arena, prototype)
    else
      _ ->
        {:ok, arena}
    end
  end
end
