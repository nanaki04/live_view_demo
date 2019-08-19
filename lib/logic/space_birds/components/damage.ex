defmodule SpaceBirds.Components.Damage do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Actions.Actions
  #alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Arena
  use Component

  @default_on_hit_effect_path "lib/master_data/space_birds/on_hit_effect_01.json"

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
      [%{payload: %{target: _target, at: at}} | _] ->
        {:ok, arena} = case component.component_data.on_hit_effect_path do
          "none" ->
            {:ok, arena}
          "default" ->
            {:ok, json} = File.read(@default_on_hit_effect_path)
            {:ok, effect} = Jason.decode(json, keys: :atoms)
            effect = put_in(effect.transform.component_data.position, at)
            Arena.add_actor(arena, effect)
          path ->
            {:ok, json} = File.read(path)
            {:ok, effect} = Jason.decode(json, keys: :atoms)
            effect = put_in(effect.transform.component_data.position, at)
            Arena.add_actor(arena, effect)
        end

        # TODO deal damage to target

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
