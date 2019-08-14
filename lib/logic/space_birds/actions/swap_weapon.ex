defmodule SpaceBirds.Actions.SwapWeapon do

  @type t :: %{
    weapon_slot: SpaceBirds.Weapons.Weapon.weapon_slot
  }

  defstruct weapon_slot: 0

end
