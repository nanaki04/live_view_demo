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
    selected_weapon: Weapon.weapon_slot,
    enabled: boolean
  }

  defstruct owner: :none,
    weapons: %{},
    selected_weapon: 0,
    enabled: true

  @impl(Component)
  def init(component, arena) do
    Arena.update_component(arena, component, fn component ->
      component = update_in(component.component_data, & Map.merge(%__MODULE__{}, &1))
      update_in(component.component_data.weapons, fn weapons ->
        Enum.map(weapons, fn {id, weapon} -> {id, Map.merge(%Weapon{}, weapon)} end)
        |> Enum.into(%{})
      end)
      |> ResultEx.return
    end)
  end

  @impl(Component)
  def run(%{component_data: %{enabled: false}}, arena) do
    {:ok, arena}
  end

  def run(component, arena) do
    {:ok, arena} = Enum.reduce(component.component_data.weapons, {:ok, arena}, fn
      {_, weapon}, {:ok, arena} -> Weapon.run(weapon, arena)
      _, error -> error
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
    {:ok, update_in(arsenal.component_data.weapons, fn weapons -> Map.put(weapons, weapon.weapon_slot, weapon) end)}
  end

  @spec run_action(Action.t, Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run_action(%{name: :swap_weapon, payload: payload}, component, arena) do
    target_weapon = payload.weapon_slot
    case Map.fetch(component.component_data.weapons, target_weapon) do
      {:ok, %{instant?: true} = weapon} ->
        Weapon.fire(weapon, %{x: 0, y: 0}, arena)
      _ ->
        Arena.update_component(arena, component, fn
          %{component_data: %{selected_weapon: ^target_weapon}} = component ->
            {:ok, put_in(component.component_data.selected_weapon, 0)}
          component ->
            {:ok, put_in(component.component_data.selected_weapon, target_weapon)}
        end)
    end
  end

  def run_action(%{name: :fire_weapon, payload: payload}, component, arena) do
    with {:ok, readonly_stats} <- Stats.get_readonly(arena, component.actor),
         false <- MapSet.member?(readonly_stats.component_data.status, :stunned),
         :none <- Stats.find_status(readonly_stats, :channeling),
         {:ok, weapon} <- Map.fetch(component.component_data.weapons, component.component_data.selected_weapon)
    do
      {:ok, arena} = if component.component_data.selected_weapon != 0 do
        Arena.update_component(arena, component, fn component ->
          {:ok, put_in(component.component_data.selected_weapon, 0)}
        end)
      else
        {:ok, arena}
      end

      Weapon.fire(weapon, payload.target, arena)
    else
      _ ->
        {:ok, arena}
    end
  end
end
