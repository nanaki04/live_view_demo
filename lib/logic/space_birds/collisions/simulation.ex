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
    |> Enum.filter(fn {target_collider, _} -> target_collider != collider end)
    |> Enum.filter(fn {target_collider, _} -> is_collider_target?(collider, target_collider) end)
    |> Enum.map(fn {_, target_transform} ->
      compare_transforms(transform, target_transform, transform.actor, target_transform.actor, collider.component_data.owner)
      |> OptionEx.or_try(fn ->
        compare_transforms(target_transform, transform, transform.actor, target_transform.actor, collider.component_data.owner)
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

  defp compare_transforms(transform, target_transform, actor, target_actor, owner) do
    Enum.reduce(Transform.get_vertices(transform), :none, fn
      point, :none ->
        Enum.reduce(Transform.get_edges(target_transform), {:some, point}, fn
          _, :none ->
            :none
          target_edge, some_point ->
            if Edge.is_starboard?(target_edge, point), do: some_point, else: :none
        end)
      _, {:some, point} ->
        {:some, point}
    end)
    |> OptionEx.or_try(fn ->
      Enum.reduce(Transform.get_edges(transform), :none, fn
        edge, :none ->
          Enum.reduce(Transform.get_edges(target_transform), :none, fn
            target_edge, :none ->
              Edge.intersects_at(edge, target_edge)
            _, {:some, point} ->
              {:some, point}
          end)
        _, {:some, point} ->
          {:some, point}
      end)
    end)
    |> OptionEx.map(fn intersection ->
      %{
        sender: {:actor, actor},
        name: :collide,
        payload: %{at: intersection, target: target_actor, owner: owner}
      }
    end)
  end

end
