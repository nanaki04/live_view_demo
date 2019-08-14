defmodule SpaceBirds.Actions.Actions do
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Players

  @type t :: [Action.t]

  @spec filter_by_action_name(t, Action.action_name) :: t
  def filter_by_action_name(actions, action_name) do
    Enum.reduce(actions, [], fn
      %{name: ^action_name} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)
  end

  @spec filter_by_action_names(t, [Action.action_name]) :: t
  def filter_by_action_names(actions, action_names) do
    Enum.reduce(actions, [], fn
      %{name: action_name} = action, actions ->
        if Enum.member?(action_names, action_name), do: [action | actions], else: actions
    end)
  end

  @spec filter_by_actor(t, Actor.t) :: t
  def filter_by_actor(actions, actor) do
     Enum.reduce(actions, [], fn
      %{sender: {:actor, ^actor}} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)
  end

  @spec filter_by_player_id(t, Players.player_id) :: t
  def filter_by_player_id(actions, player_id) do
    Enum.reduce(actions, [], fn
      %{sender: {:player, ^player_id}} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)

  end

  @spec filter_by_actor_and_player_id(t, Actor.t, Players.player_id) :: t
  def filter_by_actor_and_player_id(actions, actor, player_id) do
    Enum.reduce(actions, [], fn
      %{sender: {:player, ^player_id}} = action, actions ->
        [action | actions]
      %{sender: {:actor, ^actor}} = action, actions ->
        [action | actions]
      _, actions ->
        actions
    end)
  end

  @spec filter_by_actor_and_maybe_player_id(t, Actor.t, {:some, Players.player_id} | :none) :: t
  def filter_by_actor_and_maybe_player_id(actions, actor, :none) do
    filter_by_actor(actions, actor)
  end

  def filter_by_actor_and_maybe_player_id(actions, actor, {:some, player_id}) do
    filter_by_actor_and_player_id(actions, actor, player_id)
  end

end
