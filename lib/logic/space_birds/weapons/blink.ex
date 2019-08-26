defmodule SpaceBirds.Weapons.Blink do
  alias SpaceBirds.Weapons.Weapon
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.MasterData
  use Weapon

  @default_origin_effect_path "blink_origin"
  @default_destination_effect_path "blink_destination"

  @type t :: %{
    origin_effect_path: String.t,
    destination_effect_path: String.t,
    enhancements: [term]
  }

  defstruct origin_effect_path: "default",
    destination_effect_path: "default",
    enhancements: []

  @impl(Weapon)
  def fire(weapon, target_position, arena) do
    origin_path = case weapon.weapon_data.origin_effect_path do
      "default" -> @default_origin_effect_path
      path -> path
    end

    destination_path = case weapon.weapon_data.destination_effect_path do
      "default" -> @default_destination_effect_path
      path -> path
    end

    origin_effect_id = arena.last_actor_id + 1
    destination_effect_id = arena.last_actor_id + 2

    with {:ok, transform} <- Components.fetch(arena.components, :transform, weapon.actor),
         {:ok, origin_effect} <- MasterData.get_projectile(origin_path, origin_effect_id, weapon.actor),
         {:ok, destination_effect} <- MasterData.get_projectile(destination_path, destination_effect_id, weapon.actor)
    do
      origin_effect = put_in(origin_effect.transform.component_data.position, transform.component_data.position)
      destination_effect = put_in(destination_effect.transform.component_data.position, target_position)
      transform = put_in(transform.component_data.position, target_position)

      Arena.add_actor(arena, origin_effect)
      |> ResultEx.bind(& Arena.add_actor(&1, destination_effect))
      |> ResultEx.bind(& Arena.update_component(&1, transform, fn _ -> {:ok, transform} end))
    else
      _ ->
        {:ok, arena}
    end
  end

end
