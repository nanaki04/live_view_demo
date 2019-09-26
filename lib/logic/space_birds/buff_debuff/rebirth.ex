defmodule SpaceBirds.BuffDebuff.Rebirth do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.Lifetime
  alias SpaceBirds.Components.VisualEffectStack
  alias SpaceBirds.MasterData
  use SpaceBirds.BuffDebuff.BuffDebuff

  @default_fade_effect_path "shockwave"
  @default_revive_effect_path "divine_protection"

  @type t :: %{
    revive_time: number,
    time_until_revive: number,
    is_fading: boolean,
    fade_effect_path: String.t,
    revive_effect_path: String.t
  }

  defstruct revive_time: 5000,
    time_until_revive: 5000,
    is_fading: false,
    fade_effect_path: "default",
    revive_effect_path: "default"

  @impl(BuffDebuff)
  def on_apply(buff_debuff, buff_debuff_stack, arena) do
    buff_debuff = put_in(buff_debuff.buff_data.time_until_revive, buff_debuff.buff_data.revive_time)
    buff_debuff = put_in(buff_debuff.buff_data.is_fading, false)
    apply_default(buff_debuff, buff_debuff_stack, arena)
  end

  @impl(BuffDebuff)
  def run(rebirth, buff_debuff_stack, arena) do
    with {:ok, readonly_stats} <- Stats.get_readonly(arena, buff_debuff_stack.actor),
         hp when hp <= 0 <- readonly_stats.component_data.hp
    do
      {:ok, arena} = if rebirth.buff_data.is_fading, do: {:ok, arena}, else: fade(rebirth, buff_debuff_stack, arena)
      rebirth = put_in(rebirth.buff_data.is_fading, true)
      time_until_revive = max(0, rebirth.buff_data.time_until_revive - arena.delta_time * 1000)
      rebirth = put_in(rebirth.buff_data.time_until_revive, time_until_revive)

      {:ok, arena} = update_in_stack(rebirth, buff_debuff_stack, arena)

      if time_until_revive <= 0 do
        revive(rebirth, buff_debuff_stack, arena)
      else
        {:ok, arena}
      end
    else
      _ ->
        evaluate_expiration(rebirth, buff_debuff_stack, arena)
    end
  end

  defp fade(rebirth, buff_debuff_stack, arena) do
    {:ok, visual_effect_stack} = Components.fetch(arena.components, :visual_effect_stack, buff_debuff_stack.actor)
    {:ok, arena} = VisualEffectStack.remove_all_visual_effects(visual_effect_stack, arena)

    {:ok, arena} = play_effect(rebirth.buff_data.fade_effect_path, buff_debuff_stack.actor, arena)

    {:ok, arena} = Arena.update_component(arena, :stats, buff_debuff_stack.actor, fn stats ->
      Stats.clear_stats(stats)
    end)

    {:ok, arena} = Arena.update_components(arena, fn components ->
      {:ok, components} = Components.disable_component(components, :stats, buff_debuff_stack.actor)
      {:ok, components} = Components.disable_component(components, :movement_controller, buff_debuff_stack.actor)
      {:ok, components} = Components.disable_component(components, :arsenal, buff_debuff_stack.actor)
      {:ok, components} = Components.disable_component(components, :collider, buff_debuff_stack.actor)
      {:ok, components}
    end)

    Arena.update_component(arena, :animation_player, buff_debuff_stack.actor, fn animation_player ->
      AnimationPlayer.play_animation(animation_player, "rebirth_fighter")
    end)
  end

  defp revive(rebirth, buff_debuff_stack, arena) do
    {:ok, arena} = Arena.update_components(arena, fn components ->
      {:ok, components} = Components.enable_component(components, :stats, buff_debuff_stack.actor)
      {:ok, components} = Components.enable_component(components, :movement_controller, buff_debuff_stack.actor)
      {:ok, components} = Components.enable_component(components, :arsenal, buff_debuff_stack.actor)
      {:ok, components} = Components.enable_component(components, :collider, buff_debuff_stack.actor)
      {:ok, components}
    end)

    {:ok, arena} = spawn_projectile(rebirth.buff_data.revive_effect_path, buff_debuff_stack.actor, arena)

    {:ok, arena} = Arena.update_component(arena, :stats, buff_debuff_stack.actor, fn stats ->
      Stats.restore_to_full(stats)
    end)

    {:ok, arena} = Arena.update_component(arena, :animation_player, buff_debuff_stack.actor, fn animation_player ->
      AnimationPlayer.play_starting_animation(animation_player)
    end)

    BuffDebuff.on_remove(rebirth, buff_debuff_stack, arena)
  end

  defp play_effect("default", actor, arena) do
    play_effect(@default_fade_effect_path, actor, arena)
  end

  defp play_effect(path, actor, arena) do
    id = arena.last_actor_id + 1

    {:ok, transform} = Components.fetch(arena.components, :transform, actor)
    position = transform.component_data.position

    {:ok, effect} = MasterData.get_visual_effect(path)
    effect = put_in(effect.transform.component_data.position, position)
    effect = Map.put(effect, :lifetime, %Component{
      actor: id,
      type: "lifetime",
      component_data: %Lifetime{milliseconds: 5000}
    })

    Arena.add_actor(arena, effect)
  end

  defp spawn_projectile("default", actor, arena) do
    spawn_projectile(@default_revive_effect_path, actor, arena)

  end

  defp spawn_projectile(path, actor, arena) do
    id = arena.last_actor_id + 1

    {:ok, transform} = Components.fetch(arena.components, :transform, actor)
    position = transform.component_data.position

    {:ok, projectile} = MasterData.get_projectile(path, id, actor)
    projectile = put_in(projectile.transform.component_data.position, position)
    {:ok, projectile} = Team.copy_team(projectile, arena, actor)

    Arena.add_actor(arena, projectile)
  end

  @impl(BuffDebuff)
  def affect_stats(_buff_debuff, stats, _arena) do
    stats = update_in(stats.component_data.status, & MapSet.put(&1, :undying))
    {:ok, stats}
  end

end
