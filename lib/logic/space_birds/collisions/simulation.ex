defmodule SpaceBirds.Collision.Simulation do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Logic.Edge

  def simulate(arena) do
    {:ok, colliders} = Components.fetch(arena.components, :collider)
    {:ok, collider_and_transforms} = Enum.map(colliders, fn {actor, collider} ->
      Components.fetch(arena.components, :transform, actor)
      |> ResultEx.map(&{collider, &1})
    end)
    |> ResultEx.flatten_enum

    Task.Supervisor.async_stream(
      SpaceBirds.TaskSupervisor.Collision,
      collider_and_transforms,
      __MODULE__,
      :test_collision,
      [collider_and_transforms, self()],
      ordered: false
    )
    |> Enum.to_list

    {:ok, arena}
  end

  def test_collision({collider, transform}, colliders_and_transforms, arena_pid) do
    colliders_and_transforms
    |> Enum.filter(fn {target_collider, _} -> is_collider_target?(collider, target_collider) end)
    |> Enum.map(fn {_, target_transform} ->
      Enum.reduce(Transform.get_edges(transform), :none, fn
        _edge, {:some, target_id} ->
          {:some, target_id}
        edge, :none ->
          intersecting_edge = Enum.find(Transform.get_edges(target_transform), fn
            target_edge -> Edge.intersects?(edge, target_edge)
          end)

          case intersecting_edge  do
            nil ->
              :none
            _ ->
              {
                :some,
                %{
                  sender: {:actor, transform.actor},
                  name: :collide,
                  payload: %{actor: transform.actor, target: target_transform.actor}
                }
              }
          end
      end)
    end)
    |> OptionEx.filter_enum
    |> OptionEx.flatten_enum
    |> OptionEx.unwrap!
    |> Enum.each(fn action ->
      GenServer.cast(arena_pid, {:push_action, action})
    end)
  end

  def is_collider_target?(collider1, collider2) do
    collides_with = collider1.component_data.collides_with
    owner = collider1.component_data.owner

    Enum.member?(collides_with, collider2.component_data.layer)
    && collider2.component_data.owner != owner
  end

end
