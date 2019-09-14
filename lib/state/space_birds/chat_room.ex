defmodule SpaceBirds.State.ChatRoom do
  use GenServer, restart: :transient
  use SpaceBirds.Utility.MapAccess
  import Kernel, except: [send: 2]

  @message_limit 100

  @type chat_id :: GenServer.name

  @type message :: %{
    body: String.t,
    sender: String.t | :system
  }

  @type members :: [String.t]

  @type messages :: [message]

  @type t :: %{
    id: chat_id,
    members: %{
      Players.player_id => {pid, name :: String.t}
    },
    messages: messages
  }

  defstruct id: self(),
    members: %{},
    messages: []

  defp join_message(player_name) do
    "#{player_name} has joined!"
  end

  defp leave_message(player_name) do
    "#{player_name} has left"
  end

  def start_link([id: id]) do
    GenServer.start_link(__MODULE__, id, name: id)
  end

  @spec join(chat_id, Players.player) :: {:ok, {members, messages}} | {:error, term}
  def join(chat_id, player) do
    GenServer.call(chat_id, {:join, player})
  end

  @spec leave(chat_id) :: :ok | {:error, term}
  def leave(chat_id) do
    GenServer.call(chat_id, :leave)
  end

  @spec leave(chat_id, Players.player) :: :ok | {:error, term}
  def leave(chat_id, player) do
    GenServer.call(chat_id, {:leave, player})
  end

  @spec send(chat_id, String.t) :: {:ok, {members, messages}} | {:error, term}
  def send(chat_id, body) do
    GenServer.call(chat_id, {:send, body})
  end

  @impl(GenServer)
  def init(id) do
    {:ok, %__MODULE__{id: id}}
  end

  @impl(GenServer)
  def handle_call({:join, player}, _, state) do
    state = update_in(state.members, &Map.put(&1, player.id, {player.pid, player.name}))
    message = %{body: join_message(player.name), sender: :system}
    state = update_in(state.messages, &Enum.slice([message | &1], 0, @message_limit))
    broadcast(state, player.name)

    {:reply, {:ok, {names(state), messages(state)}}, state}
  end

  def handle_call({:send, body}, {pid, _}, state) do
    name_by_pid(state, pid)
    |> OptionEx.map(fn sender ->
      message = %{body: body, sender: sender}
      state = update_in(state.messages, &Enum.slice([message | &1], 0, @message_limit))
      broadcast(state, sender)

      {:reply, {:ok, {names(state), messages(state)}}, state}
    end)
    |> OptionEx.or_else({:reply, {:error, :sender_not_joined}, state})
  end

  def handle_call(:leave, {pid, _}, state) do
    player_by_pid(state, pid)
    |> OptionEx.map(fn {player_id, {_, player_name}} ->
      state = update_in(state.members, &Map.delete(&1, player_id))
      message = %{body: leave_message(player_name), sender: :system}
      state = update_in(state.messages, &Enum.slice([message | &1], 0, @message_limit))
      broadcast(state, player_name)

      destroy_when_empty(state)
    end)
    |> OptionEx.or_else({:reply, {:error, :sender_not_joined}, state})
  end

  def handle_call({:leave, player}, _, state) do
    state = update_in(state.members, &Map.delete(&1, player.id))
    message = %{body: leave_message(player.name), sender: :system}
    state = update_in(state.messages, &Enum.slice([message | &1], 0, @message_limit))
    broadcast(state, player.name)

    destroy_when_empty(state)
  end

  defp names(%{members: members}) do
    Enum.map(members, fn {_, {_, name}} -> name end)
  end

  defp messages(%{messages: messages}) do
    messages
  end

  defp name_by_pid(state, pid) do
    player_by_pid(state, pid)
    |> OptionEx.map(fn {_, {_, name}} -> name end)
  end

  defp player_by_pid(state, pid) do
    Enum.find(state.members, fn
      {_, {^pid, _}} -> true
      _ -> false
    end)
    |> (fn
      nil -> :none
      player -> {:some, player}
    end).()
  end

  defp broadcast(state, sender) do
    Enum.filter(state.members, fn
      {_, {_, ^sender}} -> false
      _ -> true
    end)
    |> Enum.each(fn {_, {pid, _}} ->
      Kernel.send(pid, {:chat, state.id, {names(state), messages(state)}})
    end)
  end

  # never shutdown global chat
  defp destroy_when_empty(%{id: {_, _, {_, "global"}}} = state) do
    {:reply, :ok, state}
  end

  defp destroy_when_empty(%{members: members} = state) do
    if Enum.empty?(members) do
      {:stop, :normal, :ok, state}
    else
      {:reply, :ok, state}
    end
  end

end
