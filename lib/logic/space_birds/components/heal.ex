defmodule SpaceBirds.Components.Heal do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.BuffDebuff.ImmuneTo
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  use Component

  @default_on_hit_effect_path "explosion_red_on_hit"

  @type t :: %{
    heal: number,
    on_hit_effect_paths: [String.t],
    buff_debuff_paths: [String.t],
    piercing: %{hit_cooldown: number} | false,
    on_hit: MasterData.weapon_type
  }

  defstruct heal: 0,
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
    |> filter_team_mates(actor, arena)
    |> Enum.reverse
    |> (fn
      [_ | _] = collisions ->
        case Map.fetch(component.component_data, :piercing) do
          {:ok, _} ->
            Enum.reduce(collisions, {:ok, arena}, fn
              %{payload: %{target: target, at: at, owner: owner}}, {:ok, arena} ->
                apply_heal(component, target, at, owner, arena)
              _, error ->
                error
            end)
          _ ->
            %{payload: %{target: target, at: at, owner: owner}} = hd(collisions)

            apply_heal(component, target, at, owner, arena)
        end
      _ ->
        {:ok, arena}
    end).()
  end

  defp apply_heal(component, target, at, owner, arena) do
    {:ok, {value, arena}} = case component.component_data.on_hit do
      "none" -> {:ok, {component.component_data.heal, arena}}
      weapon -> Weapon.on_hit(weapon, owner, component.component_data.heal, target, arena)
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

    # heal target
    {:ok, arena} = with {:ok, stats} <- Components.fetch(arena.components, :stats, target)
    do
      Stats.restore_shield(stats, value, arena)
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

  defp filter_team_mates(actions, actor, arena) do
    team_id = Team.find_team_id(arena, actor)

    Enum.filter(actions, fn
      %{payload: %{target: target}} ->
        OptionEx.map(team_id, fn team_id -> Team.is_ally?(team_id, target, arena) end)
        |> OptionEx.or_else(false)
      _ -> false
    end)
  end

end
