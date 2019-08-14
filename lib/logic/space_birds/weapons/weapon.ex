defmodule SpaceBirds.Weapons.Weapon do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position

  @behaviour Access

  @type weapon_data :: term

  @type weapon_slot :: number

  @type weapon_name :: String.t

  @type t :: %{
    actor: Actor.t,
    weapon_slot: weapon_slot,
    weapon_data: weapon_data,
    weapon_name: weapon_name
  }

  defstruct actor: 0,
    weapon_slot: 0,
    weapon_data: %{},
    weapon_name: :undefined

  @callback fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      @behaviour SpaceBirds.Weapons.Weapon
      @behaviour Access

      def fire(_component, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Access)
      def fetch(component, key) do
        Map.fetch(component, key)
      end

      @impl(Access)
      def get_and_update(data, key, update) do
        Map.get_and_update(data, key, update)
      end

      @impl(Access)
      def pop(data, key) do
        Map.pop(data, key)
      end

      defoverridable [fire: 3]
    end
  end

  @impl(Access)
  def fetch(component, key) do
    Map.fetch(component, key)
  end

  @impl(Access)
  def get_and_update(data, key, update) do
    Map.get_and_update(data, key, update)
  end

  @impl(Access)
  def pop(data, key) do
    Map.pop(data, key)
  end

end
