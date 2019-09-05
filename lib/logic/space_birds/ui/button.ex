defmodule SpaceBirds.UI.Button do
  alias SpaceBirds.Actions.Actions
  use SpaceBirds.UI.Node

  @type t :: %{
    id: String.t
  }

  defstruct id: "button"

  @spec find_click_events(button_id :: String.t, ui :: Component.t, Arena.t) :: [term]
  def find_click_events(button_id, component, arena) do
    Actions.filter_by_player_id(arena.actions, component.component_data.owner)
    |> Actions.filter_by_action_name(:button_click)
    |> Enum.filter(fn
      %{payload: %{id: ^button_id}} -> true
      _ -> false
    end)
    |> Enum.map(fn
      %{payload: payload} ->
        payload
      _ ->
        {:error, "No payload was found for button click event for button #{button_id}"}
    end)
  end

  @impl(Node)
  def render(node, parent, render_data_list) do
    render_data = render_default(node, parent, render_data_list)
                  |> Map.put(:button, node.node_data.id)
    render_data_list = [render_data | render_data_list]
    Node.render_children(node, parent, render_data_list)
  end

end
