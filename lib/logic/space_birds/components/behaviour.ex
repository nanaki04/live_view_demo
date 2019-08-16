defmodule SpaceBirds.Components.Behaviour do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Behaviour.Node
  alias SpaceBirds.Actions.Actions
  alias SpaceBirds.Actions.Action
  use Component

  @type t :: %{
    node_tree: Node.t,
    running_node: :none | {:some, Node.t}
  }

  defstruct node_tree: %Node{},
    running_node: :none

  @impl(Component)
  def run(component, arena) do
    component = Actions.filter_by_actor(arena.actions, component.actor)
                |> Actions.filter_by_action_name(:select_behaviour_node)
                |> (fn
                  [action | _] ->
                    put_in(component.component_data.running_node, {:some, action.payload.node})
                  _ ->
                    component
                end).()

    running_node = component.component_data.running_node
    case {Node.select(component.component_data.node_tree, component, arena), running_node} do
      {{:running, node}, {:some, running_node}} when running_node == node ->
        {:ok, node, arena} = Node.run(node, component, arena)

        Arena.update_component(arena, component, fn component ->
          {:ok, put_in(component.component_data.running_node, node)}
        end)
      {{:running, node}, _} ->
        action = %Action{name: :select_behaviour_node, sender: {:actor, component.actor}, payload: %{node: node}}
        GenServer.cast(self(), {:push_action, action})

        {:ok, arena}
      {:success, _} ->
        Arena.update_component(arena, component, fn component ->
          Node.reset(component.component_data.node_tree, component, arena)
          |> ResultEx.map(fn node -> put_in(component.component_data.node_tree, node) end)
        end)
      {:failure, _} ->
        Arena.update_component(arena, component, fn component ->
          Node.reset(component.component_data.node_tree, component, arena)
          |> ResultEx.map(fn node -> put_in(component.component_data.node_tree, node) end)
        end)
    end
  end
end
