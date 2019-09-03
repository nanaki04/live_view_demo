defmodule SpaceBirds.Components.Defeatable do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Lifetime
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Components.VisualEffectStack
  use Component

  @impl(Component)
  def run(component, arena) do
    with {:ok, stats} <- Components.fetch(arena.components, :stats, component.actor),
         hull when hull <= 0 <- stats.component_data.hp
    do
      {:ok, visual_effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
      {:ok, arena} = VisualEffectStack.remove_all_visual_effects(visual_effect_stack, arena)
      {:ok, arena} = Arena.remove_component(arena, :movement_controller, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :movement, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :arsenal, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :collider, component.actor)
      {:ok, arena} = Arena.remove_component(arena, :behaviour, component.actor)
      {:ok, arena} = Arena.remove_component(arena, component)
      {:ok, arena} = Arena.update_component(arena, :animation_player, component.actor, fn animation_player ->
        AnimationPlayer.play_animation(animation_player, "fade")
      end)
      {:ok, arena} = Arena.add_component(arena, %Component{
        actor: component.actor,
        type: :lifetime,
        component_data: %Lifetime{
          milliseconds: 1000
        }
      })
      Arena.update_component(arena, :stats, component.actor, fn stats ->
        Stats.deactivate(stats)
      end)
    else
      _ ->
        {:ok, arena}
    end
  end
end
