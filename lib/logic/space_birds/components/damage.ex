defmodule SpaceBirds.Components.Damage do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  use Component

  @default_on_hit_effect_path "01"

  @type t :: %{
    damage: number,
    on_hit_effect_path: String.t,
    piercing: boolean
  }

  defstruct damage: 1,
    on_hit_effect_path: "default",
    piercing: false

  @impl(Component)
  def run(component, arena) do
    Actions.filter_by_actor(arena.actions, component.actor)
    |> Actions.filter_by_action_name(:collide)
    |> Enum.reverse
    |> (fn
      [%{payload: %{target: target, at: at}} | _] ->
        # play on hit effect
        {:ok, arena} = case component.component_data.on_hit_effect_path do
          "none" ->
            {:ok, arena}
          "default" ->
            {:ok, effect} = MasterData.get_on_hit_effect(@default_on_hit_effect_path)
            effect = put_in(effect.transform.component_data.position, at)
            Arena.add_actor(arena, effect)
          path ->
            {:ok, effect} = MasterData.get_on_hit_effect(path)
            effect = put_in(effect.transform.component_data.position, at)
            Arena.add_actor(arena, effect)
        end

        # deal damage to target
        {:ok, arena} = Arena.update_component(arena, :stats, target, fn stats ->
          Stats.receive_damage(stats, component, arena)
        end)

        # destroy projectile
        if !component.component_data.piercing do
          Arena.remove_actor(arena, component.actor)
        else
          {:ok, arena}
        end
      _ ->
        {:ok, arena}
    end).()
  end

end
