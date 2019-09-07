defmodule SpaceBirds.Components.Stats do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.BuffDebuff
  alias SpaceBirds.Logic.Actor
  use Component

  @type status :: :stunned
    | :immune
    | :slow_resistant
    | :stun_resistant
    | {:immune_to, Actor.t | String.t}
    | {:diminishing_returns_for, BuffDebuff.buff_debuff_type, level :: number}
    | {:channeling, Weapon.weapon_slot}

  @type t :: %{
    hp: number,
    max_hp: number,
    shield: number,
    max_shield: number,
    shield_regeneration: number,
    energy: number,
    energy_regeneration: number,
    power: number,
    armor: number,
    speed: number,
    acceleration: number,
    drag: number,
    status: MapSet.t(status)
  }

  defstruct hp: 0,
    max_hp: 0,
    shield: 0,
    max_shield: 0,
    shield_regeneration: 0,
    energy: 0,
    energy_regeneration: 0,
    power: 0,
    armor: 0,
    speed: 0,
    acceleration: 0,
    status: MapSet.new()

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn component ->
      {:ok, update_in(component.component_data, & Map.put(&1, :status, MapSet.new()))}
    end)
  end

  @impl(Component)
  def run(component, arena) do
    Arena.update_component(arena, component, fn component ->
      component
      |> regenerate_shields(arena)
      |> regenerate_energy(arena)
      |> ResultEx.return
    end)
  end

  @spec receive_damage(Component.t, Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  def receive_damage(component, damage, arena) when is_number(damage) do
    {:ok, %{component_data: adjusted_stats}} = apply_buff_debuffs(component, arena)
    damage_to_shields = min(damage, component.component_data.shield)
    damage_to_hull = min(damage - damage_to_shields - adjusted_stats.armor, component.component_data.hp)
                     |> max(0)

    component = update_in(component.component_data.shield, & &1 - damage_to_shields)
    component = update_in(component.component_data.hp, & &1 - damage_to_hull)

    {:ok, component}
  end

  def receive_damage(component, damage, arena) do
    raw_damage = damage.component_data.damage
    receive_damage(component, raw_damage, arena)
  end

  @spec get_readonly(Arena.t, Actor.t) :: {:ok, Component.t} | {:error, String.t}
  def get_readonly(arena, actor) do
    Components.fetch(arena.components, :stats, actor)
    |> ResultEx.bind(fn stats -> apply_buff_debuffs(stats, arena) end)
  end

  @spec deactivate(Component.t) :: {:ok, Component.t} | {:error, String.t}
  def deactivate(component) do
    component = put_in(component.component_data.shield_regeneration, 0)
    component = put_in(component.component_data.shield, 0)
    component = put_in(component.component_data.energy_regeneration, 0)
    component = put_in(component.component_data.energy, 0)

    {:ok, component}
  end

  @spec find_diminishing_returns(Component.t, MasterData.buff_debuff_type, Arena.t) :: {:some, number} | :none
  def find_diminishing_returns(component, buff_debuff_type, arena) do
    with {:ok, stats} <- get_readonly(arena, component.actor)
    do
      stats
      |> Enum.filter(fn
        {:diminishing_returns, ^buff_debuff_type, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {_, _, level} -> level end)
      |> Enum.sort(& &1 >= &2)
      |> List.first
      |> OptionEx.return
    else
      _ ->
        :none
    end
  end

  @spec update_diminishing_returns_level(Component.t, MasterData.buff_debuff_type, (number -> number)) :: {:ok, Component.t} | {:error, String.t}
  def update_diminishing_returns_level(component, buff_debuff_type, update) do
    status = component.component_data.status
    status = Enum.find(status, fn
      {:diminishing_returns, ^buff_debuff_type, _} -> true
      _ -> false
    end)
    |> OptionEx.return
    |> OptionEx.map(fn _ ->
      Enum.map(status, fn
        {:diminishing_returns, ^buff_debuff_type, level} ->
          {:diminishing_returns, buff_debuff_type, update.(level)}
        status ->
          status
      end)
      |> Enum.into(MapSet.new)
    end)
    |> OptionEx.or_else_with(fn ->
      MapSet.put(status, {:diminishing_returns, buff_debuff_type, update.(0)})
    end)

    {:ok, put_in(component.component_data.status, status)}
  end

  @spec regenerate_shields(Component.t, Arena.t) :: Component.t
  defp regenerate_shields(component, arena) do
    {:ok, %{component_data: adjusted_stats}} = apply_buff_debuffs(component, arena)
    update_in(
      component.component_data.shield,
      & min(adjusted_stats.max_shield, &1 + adjusted_stats.shield_regeneration * arena.delta_time)
    )
  end

  @spec regenerate_energy(Component.t, Arena.t) :: Component.t
  defp regenerate_energy(component, arena) do
    {:ok, %{component_data: adjusted_stats}} = apply_buff_debuffs(component, arena)
    update_in(
      component.component_data.energy,
      & min(100, &1 + adjusted_stats.energy_regeneration * arena.delta_time)
    )
  end

  defp apply_buff_debuffs(component, arena) do
    with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, component.actor)
    do
      BuffDebuffStack.affect_stats(buff_debuff_stack, component, arena)
    else
      _ -> {:ok, component}
    end
  end

end
