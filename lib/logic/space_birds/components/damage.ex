defmodule SpaceBirds.Components.Damage do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.Tag
  alias SpaceBirds.Components.Score
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.BuffDebuff.ImmuneTo
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  use Component

  @default_on_hit_effect_path "explosion_red_on_hit"

  @type t :: %{
    damage: number,
    on_hit_effect_paths: [String.t],
    buff_debuff_paths: [String.t],
    piercing: %{hit_cooldown: number} | false,
    on_hit: MasterData.weapon_type
  }

  defstruct damage: 1,
    on_hit_effect_paths: ["default"],
    buff_debuff_paths: [],
    piercing: false,
    on_hit: "none"

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn component ->
      update_in(component.component_data, & Map.merge(%__MODULE__{}, &1))
      |> ResultEx.return
    end)
  end

  @impl(Component)
  def run(component, arena) do
    actor = component.actor

    Actions.filter_by_actor(arena.actions, component.actor)
    |> Actions.filter_by_action_name(:collide)
    |> without_friendly_fire(component.actor, arena)
    |> Enum.reverse
    |> (fn
      [_ | _] = collisions ->
        case Map.fetch(component.component_data, :piercing) do
          {:ok, _} ->
            Enum.reduce(collisions, {:ok, arena}, fn
              %{payload: %{target: target, at: at, owner: owner}}, {:ok, arena} ->
                unless target_is_immune?(target, actor, arena) do
                  apply_damage(component, target, at, owner, arena)
                else
                  {:ok, arena}
                end
              _, error ->
                error
            end)
          _ ->
            %{payload: %{target: target, at: at, owner: owner}} = hd(collisions)

            unless target_is_immune?(target, actor, arena) do
              apply_damage(component, target, at, owner, arena)
            else
              {:ok, arena}
            end
        end
      _ ->
        {:ok, arena}
    end).()
  end

  defp target_is_immune?(target, actor, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, target),
         false <- MapSet.member?(readonly_stats.status, {:immune_to, actor}),
         false <- MapSet.member?(readonly_stats.status, {:immune_to, Tag.find_tag(arena, actor)}),
         false <- MapSet.member?(readonly_stats.status, :immune)
    do
      false
    else
      _ ->
        true
    end
  end

  defp apply_damage(component, target, at, owner, arena) do
    {:ok, component} = case component.component_data.on_hit do
      "none" -> {:ok, component}
      weapon -> Weapon.on_hit(weapon, owner, component, arena)
    end

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
    {:ok, arena} = with {:ok, stats} <- Components.fetch(arena.components, :stats, target)
    do
      life = stats.component_data.hp + stats.component_data.shield
      {:ok, arena} = Stats.receive_damage(stats, component, arena)
      {:ok, stats} = Components.fetch(arena.components, :stats, target)
      damage_done = life - (stats.component_data.hp + stats.component_data.shield)
      {:ok, arena} = Score.log_damage(arena, damage_done, target, owner)
      if stats.component_data.hp <= 0 do
        Score.log_kill(arena, target, owner)
      else
        {:ok, arena}
      end
    else
      _ ->
        {:ok, arena}
    end

    # apply buff / debuffs
    {:ok, arena} = Enum.reduce(component.component_data.buff_debuff_paths, {:ok, arena}, fn
      "", {:ok, arena} ->
        {:ok, arena}
      "none", {:ok, arena} ->
        {:ok, arena}
      "default", {:ok, arena} ->
        {:ok, arena}
      path, {:ok, arena} ->
        with {:ok, buff_debuff} <- MasterData.get_buff_debuff(path, owner),
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

  defp without_friendly_fire(actions, actor, arena) do
    owner = case Components.fetch(arena.components, :owner, actor) do
      {:ok, owner} -> owner.component_data.owner
      _ -> actor
    end

    collider = case Components.fetch(arena.components, :collider, actor) do
      {:ok, collider} -> collider.component_data.owner
      _ -> actor
    end

    team_id = Team.find_team_id(arena, actor)

    Enum.filter(actions, fn
      %{payload: %{target: target}} ->
        is_ally? = OptionEx.map(team_id, fn team_id -> Team.is_ally?(team_id, target, arena) end)
                   |> OptionEx.or_else(false)
        target != owner && target != collider && !is_ally?
      _ -> false
    end)
  end

end
