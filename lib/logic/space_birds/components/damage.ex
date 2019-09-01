defmodule SpaceBirds.Components.Damage do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.BuffDebuff.ImmuneTo
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  use Component

  @default_on_hit_effect_path "01"

  @type t :: %{
    damage: number,
    on_hit_effect_paths: [String.t],
    buff_debuff_paths: [String.t],
    piercing: %{hit_cooldown: number} | false
  }

  defstruct damage: 1,
    on_hit_effect_paths: ["default"],
    buff_debuff_paths: [],
    piercing: false

  @impl(Component)
  def run(component, arena) do
    actor = component.actor

    Actions.filter_by_actor(arena.actions, component.actor)
    |> Actions.filter_by_action_name(:collide)
    |> Enum.reverse
    |> (fn
      [%{payload: %{target: target, at: at}} | _] ->
        with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, target),
             false <- MapSet.member?(readonly_stats.status, {:immune_to, actor}),
             false <- MapSet.member?(readonly_stats.status, {:immune_to, Tag.find_tag(arena, actor)}),
             false <- MapSet.member?(readonly_stats.status, :immune)
        do
          apply_damage(component, target, at, arena)
        else
          _ ->
            {:ok, arena}
        end
      _ ->
        {:ok, arena}
    end).()
  end

  defp apply_damage(component, target, at, arena) do
    # play on hit effects
    {:ok, arena} = Enum.reduce(component.component_data.on_hit_effect_paths, {:ok, arena}, fn
      "", {:ok, arena} ->
        {:ok, arena}
      "none", {:ok, arena} ->
        {:ok, arena}
      "default", {:ok, arena} ->
        {:ok, effect} = MasterData.get_on_hit_effect(@default_on_hit_effect_path)
        effect = put_in(effect.transform.component_data.position, at)
        Arena.add_actor(arena, effect)
      path, {:ok, arena} ->
        {:ok, effect} = MasterData.get_on_hit_effect(path)
        effect = put_in(effect.transform.component_data.position, at)
        Arena.add_actor(arena, effect)
      _, error ->
        error
    end)

    # deal damage to target
    {:ok, arena} = Arena.update_component(arena, :stats, target, fn stats ->
      Stats.receive_damage(stats, component, arena)
    end)

    # apply buff / debuffs
    {:ok, arena} = Enum.reduce(component.component_data.buff_debuff_paths, {:ok, arena}, fn
      "", {:ok, arena} ->
        {:ok, arena}
      "none", {:ok, arena} ->
        {:ok, arena}
      "default", {:ok, arena} ->
        {:ok, arena}
      path, {:ok, arena} ->
        with {:ok, buff_debuff} <- MasterData.get_buff_debuff(path),
             {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, target)
        do
          BuffDebuffStack.apply(buff_debuff_stack, buff_debuff, arena)
        else
          _ -> {:ok, arena}
        end
      _, error ->
        error
    end)

    # destroy projectile, or set temporary immunity for piercing projectiles
    case Map.fetch(component.component_data, :piercing) do
      {:ok, %{hit_cooldown: 0}} ->
        {:ok, arena}
      {:ok, %{hit_cooldown: hit_cooldown}} ->
        with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, target)
        do
          immunity = ImmuneTo.new(component.actor, hit_cooldown)
          BuffDebuffStack.apply(buff_debuff_stack, immunity, arena)
        else
          _ ->
            {:ok, arena}
        end
      _ ->
        Arena.remove_actor(arena, component.actor)
    end

  end

end
