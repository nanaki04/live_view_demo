defmodule SpaceBirds.Actions.Action do
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.Arena
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
    | :select_behaviour_node

  @type payload :: term

  @type t :: %{
    sender: sender,
    name: action_name,
    payload: payload
  }

  defstruct sender: :system,
    name: :undefined,
    payload: %{}

  @callback init(t, Arena.t) :: {:ok, t} | {:error, String.t}

  def init(action, arena) do
    module_name = action.name
                  |> Atom.to_string
                  |> String.split("_")
                  |> Enum.map(&String.capitalize/1)
                  |> Enum.join
                  |> (& Module.concat(SpaceBirds.Actions, &1)).()

    if function_exported?(module_name, :init, 2) do
      apply(module_name, :init, [action, arena])
    else
      {:ok, action}
    end
  end

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
