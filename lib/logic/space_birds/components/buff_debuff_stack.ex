defmodule SpaceBirds.Components.BuffDebuffStack do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.BuffDebuff.BuffDebuff
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.MasterData
  import Kernel, except: [apply: 3]
  use Component

  @type t :: %{
    buff_debuffs: %{
      required(:last_id) => number,
      optional(number) => BuffDebuff.t
    }
  }

  defstruct buff_debuffs: %{last_id: 0}

  @impl(Component)
  def run(component, arena) do
    Enum.reduce(component.component_data.buff_debuffs, {:ok, arena}, fn
      {:last_id, _}, {:ok, arena} ->
        {:ok, arena}
      {_, buff_debuff}, {:ok, arena} ->
        {:ok, buff_debuff_stack} = Components.fetch(arena.components, :buff_debuff_stack, component.actor)
        BuffDebuff.run(buff_debuff, buff_debuff_stack, arena)
      _, error ->
        error
    end)
  end

  @spec apply(Component.t, BuffDebuff.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def apply(component, buff_debuff, arena) do
    BuffDebuff.on_apply(buff_debuff, component, arena)
  end

  @spec affect_stats(Component.t, stats :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  def affect_stats(component, stats, arena) do
    Enum.reduce(component.component_data.buff_debuffs, {:ok, stats}, fn
      {:last_id, _}, value ->
        value
      {_, buff_debuff}, {:ok, stats} ->
        BuffDebuff.affect_stats(buff_debuff, stats, arena)
      _, error ->
        error
    end)
  end

  @spec remove_by_type(Component.t, MasterData.buff_debuff_type, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def remove_by_type(component, buff_debuff_type, arena) do
    filter_by_type(component, buff_debuff_type)
    |> Enum.reduce({:ok, arena}, fn
      buff_debuff, {:ok, arena} ->
        {:ok, component} = Components.fetch(arena.components, :buff_debuff_stack, component.actor)
        BuffDebuff.on_remove(buff_debuff, component, arena)
      _, error -> error
    end)
  end

  @spec filter_by_type(Component.t, MasterData.buff_debuff_type) :: [BuffDebuff.t]
  def filter_by_type(component, buff_debuff_type) do
    Enum.filter(component.component_data.buff_debuffs, fn
      {_, %{type: ^buff_debuff_type}} -> true
      _ -> false
    end)
    |> Enum.map(fn {_, buff_debuff} -> buff_debuff end)
  end

  @spec count_by_type(Component.t, MasterData.buff_debuff_type) :: number
  def count_by_type(component, buff_debuff_type) do
    length(filter_by_type(component, buff_debuff_type))
  end

end
