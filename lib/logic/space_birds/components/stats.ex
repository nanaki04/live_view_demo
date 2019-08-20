defmodule SpaceBirds.Components.Stats do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Component
  use Component

  @type t :: %{
    hp: number,
    max_hp: number,
    shield: number,
    max_shield: number,
    shield_regeneration: number,
    energy: number,
    energy_regeneration: number,
    power: number,
    armor: number
  }

  defstruct hp: 0,
    max_hp: 0,
    shield: 0,
    max_shield: 0,
    shield_regeneration: 0,
    energy: 0,
    energy_regeneration: 0,
    power: 0,
    armor: 0

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
  def receive_damage(component, damage, _arena) do
    raw_damage = damage.component_data.damage
    damage_to_shields = min(raw_damage, component.component_data.shield)
    damage_to_hull = min(raw_damage - damage_to_shields - component.component_data.armor, component.component_data.hp)
                     |> max(0)

    component = update_in(component.component_data.shield, & &1 - damage_to_shields)
    component = update_in(component.component_data.hp, & &1 - damage_to_hull)

    {:ok, component}
  end

  @spec regenerate_shields(Component.t, Arena.t) :: Component.t
  defp regenerate_shields(component, arena) do
    update_in(
      component.component_data.shield,
      & min(component.component_data.max_shield, &1 + component.component_data.shield_regeneration * arena.delta_time)
    )
  end

  @spec regenerate_energy(Component.t, Arena.t) :: Component.t
  defp regenerate_energy(component, arena) do
    update_in(
      component.component_data.energy,
      & min(100, &1 + component.component_data.energy_regeneration * arena.delta_time)
    )
  end

end
