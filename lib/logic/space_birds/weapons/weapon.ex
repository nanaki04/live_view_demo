defmodule SpaceBirds.Weapons.Weapon do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position
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
    cooldown_remaining: number
  }

  defstruct actor: 0,
    weapon_slot: 0,
    weapon_data: %{},
    weapon_name: :undefined,
    icon: "white",
    cooldown: 500,
    cooldown_remaining: 0

  @callback fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_cooldown(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      use SpaceBirds.Utility.MapAccess
      alias SpaceBirds.Weapons.Weapon
      @behaviour Weapon

      @impl(Weapon)
      def fire(_component, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Weapon)
      def on_cooldown(_component, _target_position, arena) do
        {:ok, arena}
      end

      defoverridable [fire: 3]
    end
  end

  @spec fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def fire(weapon, target_position, arena) do
    module_name = weapon.weapon_name
                  |> String.split("_")
                  |> Enum.map(&String.capitalize/1)
                  |> Enum.join

    full_module_name = Module.concat(SpaceBirds.Weapons, module_name)

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

  @spec cool_down(t, Arena.t) :: t
  def cool_down(weapon, arena) do
    update_in(weapon.cooldown_remaining, & max(0, &1 - arena.delta_time * 1000))
  end

  @spec cooldown_progress(t) :: number
  def cooldown_progress(weapon) do
    1 - (weapon.cooldown_remaining / weapon.cooldown)
  end

  defp is_on_cooldown?(weapon) do
    weapon.cooldown_remaining > 0
  end

  defp start_cooling_down(weapon) do
    put_in(weapon.cooldown_remaining, weapon.cooldown)
  end

end
