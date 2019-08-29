defmodule SpaceBirds.Actions.FireWeapon do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Camera

  @behaviour Action

  @type t :: %{
    target: Position.t
  }

  defstruct target: %Position{}

  @impl(Action)
  def init(%{sender: {:player, player_id}, payload: payload} = action, arena) do
    with {:ok, cameras} <- Components.fetch(arena.components, :camera),
         {_, camera} <- Enum.find(cameras, fn {_, camera} -> camera.component_data.owner == player_id end),
         {:ok, target} <- Camera.convert_grid_point_to_game_point(camera, payload.target, arena)
    do
      action = put_in(action.payload.target, target)

      {:ok, action}
    else
      _ ->
        {:ok, action}
    end
  end

end
