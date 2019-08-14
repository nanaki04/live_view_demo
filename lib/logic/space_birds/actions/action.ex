defmodule SpaceBirds.Actions.Action do
  alias SpaceBirds.State.Players
  alias SpaceBirds.Logic.Actor

  @behaviour Access

  @type sender :: {:player, Players.player_id}
    | {:actor, Actor.t}
    | :system

  @type action_name :: :undefined
    | :move_up_start
    | :move_up_stop
    | :move_down_start
    | :move_down_stop
    | :move_left_start
    | :move_left_stop
    | :move_right_start
    | :move_right_stop
    | :select_weapon
    | :deselect_weapon
    | :fire_weapon

  @type payload :: term

  @type t :: %{
    sender: sender,
    name: action_name,
    payload: payload
  }

  defstruct sender: :system,
    name: :undefined,
    payload: %{}

  @impl(Access)
  def fetch(component, key) do
    Map.fetch(component, key)
  end

  @impl(Access)
  def get_and_update(data, key, update) do
    Map.get_and_update(data, key, update)
  end

  @impl(Access)
  def pop(data, key) do
    Map.pop(data, key)
  end

end
