defmodule SpaceBirds.Components.Defeatable do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Components.Lifetime
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Components.VisualEffectStack
  alias SpaceBirds.Components.PlayerSpawner
  alias SpaceBirds.MasterData
  use Component

  @type spawn_item :: %{
    path: String.t,
    weight: number
  }

  @type t :: %{
    spawn_on_death: String.t | [spawn_item],
    is_defeated?: boolean
  }

  defstruct spawn_on_death: "none",
  is_defeated?: false

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn _ ->
      component = update_in(component.component_data, & Map.merge(%__MODULE__{}, &1))
      {:ok, component}
    end)
  end

  @impl(Component)
  def run(component, arena) do
    {:ok, arena} = despawn(component, arena)
    respawn(component, arena)
  end

  defp despawn(component, arena) do
    with false <- component.component_data.is_defeated?,
         {:ok, stats} <- Components.fetch(arena.components, :stats, component.actor),
         hull when hull <= 0 <- stats.component_data.hp
    do
      {:ok, visual_effect_stack} = Components.fetch(arena.components, :visual_effect_stack, component.actor)
      {:ok, arena} = VisualEffectStack.remove_all_visual_effects(visual_effect_stack, arena)
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
        Stats.clear_stats(stats)
      end)

      {:ok, arena} = Arena.update_components(arena, fn components ->
        {:ok, components} = Components.disable_component(components, :stats, component.actor)
        {:ok, components} = Components.disable_component(components, :movement_controller, component.actor)
        {:ok, components} = Components.disable_component(components, :movement, component.actor)
        {:ok, components} = Components.disable_component(components, :arsenal, component.actor)
        {:ok, components} = Components.disable_component(components, :collider, component.actor)
        {:ok, components} = Components.disable_component(components, :behaviour, component.actor)
        {:ok, components} = Components.disable_component(components, :tag, component.actor)

        {:ok, components}
      end)

      {:ok, arena} = Arena.update_component(arena, :animation_player, component.actor, fn animation_player ->
        AnimationPlayer.play_animation(animation_player, "fade")
      end)

      {:ok, arena} = spawn_on_death(component, arena)

      Arena.update_component(arena, component, fn component ->
        {:ok, put_in(component.component_data.is_defeated?, true)}
      end)
    else
      _ ->
        {:ok, arena}
    end
  end

  defp respawn(component, arena) do
    with true <- component.component_data.is_defeated?,
         {:ok, player_spawner} <- Components.fetch(arena.components, :player_spawner, component.actor),
         time_until_respawn when time_until_respawn <= 0 <- player_spawner.component_data.time_until_respawn
    do
      {:ok, arena} = Arena.update_components(arena, fn components ->
        {:ok, components} = Components.enable_component(components, :stats, component.actor)
        {:ok, components} = Components.enable_component(components, :movement_controller, component.actor)
        {:ok, components} = Components.enable_component(components, :movement, component.actor)
        {:ok, components} = Components.enable_component(components, :arsenal, component.actor)
        {:ok, components} = Components.enable_component(components, :collider, component.actor)
        {:ok, components} = Components.enable_component(components, :behaviour, component.actor)
        {:ok, components} = Components.enable_component(components, :tag, component.actor)

        {:ok, components}
      end)

      {:ok, arena} = Arena.update_component(arena, :stats, component.actor, fn stats ->
        Stats.restore_to_full(stats)
      end)

      {:ok, arena} = Arena.update_component(arena, :animation_player, component.actor, fn animation_player ->
        AnimationPlayer.play_starting_animation(animation_player)
      end)

      {:ok, arena} = PlayerSpawner.set_spawn_position(player_spawner, arena)

      Arena.update_component(arena, component, fn component ->
        {:ok, put_in(component.component_data.is_defeated?, false)}
      end)
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
