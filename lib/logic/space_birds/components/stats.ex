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

  @spec receive_damage(Component.t, Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  def receive_damage(component, damage, _arena) do
    {:ok, update_in(component.component_data.hp, & max(0, &1 - max(0, damage.component_data.damage - component.component_data.armor)))}
  end

end
