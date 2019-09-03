defmodule SpaceBirds.Behaviour.AttackNearestTarget do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Transform
  alias SpaceBirds.Components.Tag
  use SpaceBirds.Behaviour.Node

  @type t :: %{
    target: Tag.tag | [Tag.tag]
  }

  defstruct target: "default"

  @impl(Node)
  def init(node, _, _, _) do
    {:ok, node}
  end

  @impl(Node)
  def select(node, component, arena) do
    with {:ok, actors} <- Tag.find_actors_by_tag(arena, node.node_data.target),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, _} <- Transform.find_closest_target(transform, transforms)
    do
      {:running, node}
    else
      _ ->
        :failure
    end
  end

  @impl(Node)
  def run(node, component, arena) do
    with {:ok, actors} <- Tag.find_actors_by_tag(arena, node.node_data.target),
         {:ok, transforms} <- Enum.map(actors, & Components.fetch(arena.components, :transform, &1))
                              |> ResultEx.flatten_enum,
         {:ok, transform} <- Components.fetch(arena.components, :transform, component.actor),
         {:some, closest_target} <- Transform.find_closest_target(transform, transforms)
    do
      action = %{
        sender: {:actor, component.actor},
        name: :fire_weapon,
        payload: %{target: closest_target.component_data.position}
      }

      :ok = GenServer.cast(self(), {:push_action, action})

      {:ok, node, arena}
    else
      _ ->
        {:ok, node, arena} 
    end
  end

end
