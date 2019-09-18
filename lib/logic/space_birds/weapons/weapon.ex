defmodule SpaceBirds.Weapons.Weapon do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Arsenal
  use SpaceBirds.Utility.MapAccess

  @type weapon_data :: term

  @type weapon_slot :: number

  @type weapon_name :: String.t

  @type t :: %{
    actor: Actor.t,
    weapon_slot: weapon_slot,
    weapon_data: weapon_data,
    weapon_name: weapon_name,
    icon: String.t,
    cooldown: number,
    cooldown_remaining: number,
    instant?: boolean
  }

  defstruct actor: 0,
    weapon_slot: 0,
    weapon_data: %{},
    weapon_name: :undefined,
    icon: "white",
    cooldown: 500,
    cooldown_remaining: 0,
    instant?: false

  @callback fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_cooldown(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback run(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_hit(t, damage :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      use SpaceBirds.Utility.MapAccess
      alias SpaceBirds.Weapons.Weapon
      @behaviour Weapon

      @impl(Weapon)
      def fire(_weapon, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Weapon)
      def on_cooldown(_weapon, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Weapon)
      def run(weapon, arena) do
        cool_down(weapon, arena)
      end

      @impl(Weapon)
      def on_hit(_, damage, _) do
        {:ok, damage}
      end

      defp cool_down(weapon, arena) do
        Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
          weapon = update_in(weapon.cooldown_remaining, & max(0, &1 - arena.delta_time * 1000))
          Arsenal.put_weapon(arsenal, weapon)
        end)
      end

      defoverridable [fire: 3, run: 2, on_cooldown: 3, on_hit: 3]
    end
  end

  @spec fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def fire(weapon, target_position, arena) do
    full_module_name = find_module_name(weapon.weapon_name)

    if is_on_cooldown?(weapon) do
      apply(full_module_name, :on_cooldown, [weapon, target_position, arena])
    else
      weapon = start_cooling_down(weapon)
      {:ok, arena} = Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
        Arsenal.put_weapon(arsenal, weapon)
      end)

      apply(full_module_name, :fire, [weapon, target_position, arena])
    end
  end

  @spec run(t, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def run(weapon, arena) do
    find_module_name(weapon.weapon_name)
    |> apply(:run, [weapon, arena])
  end

  @spec cooldown_progress(t) :: number
  def cooldown_progress(weapon) do
    1 - (weapon.cooldown_remaining / weapon.cooldown)
  end

  def on_hit(weapon_type, actor, damage, arena) do
    with {:ok, arsenal} <- Components.fetch(arena.components, :arsenal, actor),
         {_, weapon} <- Enum.find(arsenal.component_data.weapons, &(elem(&1, 1).weapon_name == weapon_type))
    do
      module_name = find_module_name(weapon_type)
      apply(module_name, :on_hit, [weapon, damage, arena])
    else
      _ ->
        {:ok, damage}
    end
  end

  defp is_on_cooldown?(weapon) do
    weapon.cooldown_remaining > 0
  end

  defp start_cooling_down(weapon) do
    put_in(weapon.cooldown_remaining, weapon.cooldown)
  end

  defp find_module_name(weapon_name) do
    weapon_name
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Weapons, &1)).()
  end

end
