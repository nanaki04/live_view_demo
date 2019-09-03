defmodule SpaceBirds.Components.Spawner do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena
  alias SpaceBirds.MasterData
  use Component

  @type t :: %{
    children: [Actor.t],
    prototype: MasterData.prototype,
    max_children: number,
    interval: number
  }

  defstruct children: [],
    prototype: "none",
    max_children: 0,
    interval: 0,
    time_until_next_spawn: 0

  @impl(Component)
  def init(component, arena) do
    component_data = Map.merge(%__MODULE__{}, component.component_data)
    Arena.update_component(arena, component, fn component ->
      {:ok, put_in(component.component_data, component_data)}
    end)
  end

  @impl(Component)
  def run(component, arena) do
    component = update_in(component.component_data.children, fn children ->
      Enum.filter(children, fn child ->
        :ok == Components.fetch(arena.components, :transform, child)
               |> elem(0)
      end)
    end)

    {:ok, arena} = Arena.update_component(arena, component, fn _ -> {:ok, component} end)

    max_children = component.component_data.max_children

    {:ok, arena} = with children when length(children) < max_children <- component.component_data.children
    do
      component = update_in(component.component_data.time_until_next_spawn, &(&1 - arena.delta_time * 1000))

      Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    else
      _ ->
        {:ok, arena}
    end

    prototype_id = arena.last_actor_id + 1

    with children when length(children) < max_children <- component.component_data.children,
         time_until_next_spawn when time_until_next_spawn <= 0 <- component.component_data.time_until_next_spawn,
         {:ok, prototype} <- MasterData.get_prototype(component.component_data.prototype, prototype_id),
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor)
    do
      component = put_in(component.component_data.time_until_next_spawn, component.component_data.interval)
      component = update_in(component.component_data.children, &[prototype_id | &1])
      prototype = put_in(prototype.transform.component_data.position, transform.component_data.position)

      {:ok, arena} = Arena.add_actor(arena, prototype)
      Arena.update_component(arena, component, fn _ -> {:ok, component} end)
    else
      _ ->
        {:ok, arena}
    end
  end

end
