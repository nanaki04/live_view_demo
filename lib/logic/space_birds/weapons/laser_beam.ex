defmodule SpaceBirds.Weapons.LaserBeam do
  alias SpaceBirds.Weapons.Weapon
  use Weapon

  @default_projectile_path "lib/master_data/space_birds/laser_beam.json"

  @type t :: %{
    projectile_path: String.t,
    enhancements: [term]
  }

  defstruct projectile_path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(_weapon, _target_position, arena) do
    IO.inspect("fire laser beam!")
    {:ok, arena}
  end

end
