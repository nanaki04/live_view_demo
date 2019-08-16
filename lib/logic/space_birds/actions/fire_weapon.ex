defmodule SpaceBirds.Actions.FireWeapon do
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.Components.Components
  alias SpaceBirds.State.Arena

  @behaviour Action

  @type t :: %{
    target: Position.t
  }

  defstruct target: %Position{}

  @impl(Action)
  def init(%{sender: {:player, player_id}, payload: payload} = action, arena) do
    {:ok, cameras} = Components.fetch(arena.components, :camera)
    with {_, %{actor: actor}} <- Enum.find(cameras, fn {_, camera} -> camera.component_data.owner == player_id end),
         {:ok, transform} <- Components.fetch(arena.components, :transform, actor),
         {:ok, %{resolution: {res_x, res_y}}} <- Arena.find_player(arena, player_id)
    do
      zero_point = Vector2.sub(transform.component_data.position, %{x: res_x / 2, y: res_y / 2})
      target = Vector2.mul(payload.target, 100)
               |> Vector2.add(50)
               |> Vector2.add(zero_point)

      action = put_in(action.payload.target, target)

      {:ok, action}
    else
      _ ->
        {:ok, action}
    end
  end

end
