defmodule SpaceBirds.Components.Arsenal do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.Actions.Action
  use Component

  @type t :: %{
    owner: {:some, Players.player_id} | :none,
    weapons: %{Weapon.weapon_slot => Weapon.t},
    selected_weapon: Weapon.weapon_slot
  }

  defstruct owner: :none,
    weapons: %{},
    selected_weapon: 0

  @impl(Component)
  def run(component, arena) do
    {:ok, arena} = Arena.update_component(arena, component, fn component ->
      update_in(component.component_data.weapons, fn weapons ->
        Enum.map(weapons, fn {slot, weapon} -> {slot, Weapon.cool_down(weapon, arena)} end)
        |> Enum.into(%{})
      end)
      |> ResultEx.return
    end)

    Actions.filter_by_actor_and_maybe_player_id(arena.actions, component.actor, component.component_data.owner)
    |> Actions.filter_by_action_names([:swap_weapon, :fire_weapon])
    |> Enum.reverse
    |> Enum.reduce({:ok, arena}, fn
      _, {:error, reason} ->
        {:error, reason}
      action, {:ok, arena} ->
        run_action(action, component, arena)
    end)
  end

  @spec put_weapon(t, Weapon.t) :: {:ok, t} | {:error, String.t}
  def put_weapon(arsenal, weapon) do
    {:ok, put_in(arsenal.component_data.weapons[weapon.weapon_slot], weapon)}
  end

  @spec run_action(Action.t, Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run_action(%{name: :swap_weapon, payload: payload}, component, arena) do
    target_weapon = payload.weapon_slot
    Arena.update_component(arena, component, fn
      %{component_data: %{selected_weapon: ^target_weapon}} = component ->
        {:ok, put_in(component.component_data.selected_weapon, 0)}
      component ->
        {:ok, put_in(component.component_data.selected_weapon, target_weapon)}
    end)
  end

  def run_action(%{name: :fire_weapon, payload: payload}, component, arena) do
    with {:ok, %{component_data: readonly_stats}} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(readonly_stats.status, :stunned),
         {:ok, weapon} = Map.fetch(component.component_data.weapons, component.component_data.selected_weapon)
    do
      {:ok, arena} = if component.component_data.selected_weapon != 0 do
        Arena.update_component(arena, component, fn component ->
          {:ok, put_in(component.component_data.selected_weapon, 0)}
        end)
      else
        {:ok, arena}
      end

      Weapon.fire(weapon, payload.target, arena)
    end
  end
end
