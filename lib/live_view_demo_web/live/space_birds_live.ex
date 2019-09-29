defmodule LiveViewDemoWeb.SpaceBirdsLive do
  use Phoenix.LiveView
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.ChatRoom
  alias SpaceBirds.State.ChatSupervisor
  alias SpaceBirds.State.BackPressureSystem
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.Actions.SwapWeapon
  alias SpaceBirds.Actions.FireWeapon
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.MasterData
  alias SpaceBirds.UI.Button

  @impl(Phoenix.LiveView)
  def render(%{state: %{location: :main_menu}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "main_menu.html", assigns)
  end

  def render(%{state: %{location: :arena}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "arena.html", assigns)
  end

  def render(%{state: %{location: :result}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "result.html", assigns)
  end

  @impl(Phoenix.LiveView)
  def mount(_session, socket) do
    socket
    |> assign(:state, %SpaceBirds.State.Application{})
    |> assign(:player, nil)
    |> assign(:chat, {nil, [], []})
    |> assign(:typing, false)
    |> assign(:render_data, [])
    |> assign(:battle_list, [])
    |> assign(:selected_battle, "new")
    |> assign(:fighter_types, ResultEx.unwrap!(MasterData.get_fighter_types()))
    |> assign(:selected_fighter_type, "hawk")
    |> assign(:fighter_confirmed, false)
    |> assign(:version, 0)
    |> assign(:fps, 30)
    |> assign(:error, nil)
    |> ok
  end

  @impl(Phoenix.LiveView)
  def handle_event("new_player", %{"player_name" => ""}, socket) do
    socket
    |> noreply
  end

  def handle_event("new_player", %{"player_name" => player_name}, socket) do
    {:ok, player} = Players.join(self(), player_name)
    chat_id = ChatSupervisor.global_chat_id
    {:ok, {members, messages}} = ChatRoom.join(chat_id, player)

    assign(socket, player: player)
    |> assign(:fighter_information, ResultEx.unwrap!(SpaceBirds.MasterData.get_fighter_information(socket.assigns.selected_fighter_type)))
    |> assign(:chat, {chat_id, members, messages})
    |> noreply
  end

  def handle_event(
    "start_game",
    _,
    %{assigns: %{player: player, state: state, selected_battle: selected_battle, selected_fighter_type: fighter_type}} = socket
  ) do
    {chat_id, _, _} = socket.assigns.chat
    ChatRoom.leave(chat_id, player)

    {:ok, battle_id, chat_id} = if selected_battle == "new" do
      {:ok, battle_id} = SpaceBirds.State.ArenaSupervisor.start_child()
      {_via, _Registry, {_ArenaRegistry, raw_id}} = battle_id
      {:ok, chat_id} = SpaceBirds.State.ChatSupervisor.start_child(raw_id)
      {:ok, battle_id, chat_id}
    else
      battle_id = {:via, Registry, {SpaceBirds.State.ArenaRegistry, selected_battle}}
      {:ok, battle_id, ChatSupervisor.via(selected_battle)}
    end

    with :ok <- GenServer.call(battle_id, {:join, player, fighter_type}),
         {:ok, player} <- Players.update(player.id, fn player -> Map.put(player, :battle_id, battle_id) end),
         {:ok, {members, messages}} <- ChatRoom.join(chat_id, player)
    do
      socket
      |> assign(player: player)
      |> assign(battle: battle_id)
      |> assign(chat: {chat_id, members, messages})
      |> assign(state: Map.put(state, :location, :arena))
      |> assign(:error, nil)
      |> noreply
    else
      {:error, :battle_full} ->
        socket
        |> assign(:error, "Unable to join, the selected battle is full. Please select a different one.")
        |> assign(:battle_list, SpaceBirds.State.ArenaRegistry.list_all_joinable())
        |> noreply
      _ ->
        socket
        |> assign(:error, "An unknown error occurred. Please try again.")
        |> noreply
    end
  end

  def handle_event("update_client_version", version, socket) do
    battle_id = socket.assigns.battle
    player_id = socket.assigns.player.id

    BackPressureSystem.id(player_id, battle_id)
          |> GenServer.whereis
          |> OptionEx.return
          |> OptionEx.map(fn pid -> BackPressureSystem.confirm(pid, version) end)

    {:noreply, socket}
  end

  def handle_event("grid", value, socket) do
    position = String.split(value, "_")
               |> Enum.map(&Integer.parse/1)
               |> Enum.map(&elem(&1, 0))
               |> Position.new

    push_action(:fire_weapon, %FireWeapon{grid_point: position}, socket)

    {:noreply, socket}
  end

  def handle_event("key_up", key, %{assigns: %{typing: false}} = socket) do
    socket = case key do
      "w" -> push_action(:move_up_stop, socket)
      "s" -> push_action(:move_down_stop, socket)
      "d" -> push_action(:move_right_stop, socket)
      "a" -> push_action(:move_left_stop, socket)
      "Escape" -> push_action(:cancel, socket)
        # debug only
      "u" ->
        fps = GenServer.call(socket.assigns.battle, :fps_up)
        socket = assign(socket, :fps, fps)
      "j" ->
        fps = GenServer.call(socket.assigns.battle, :fps_down)
        socket = assign(socket, :fps, fps)
      _ -> socket
    end

    {:noreply, socket}
  end

  def handle_event("key_down", key, %{assigns: %{typing: false}} = socket) do
    socket = case key do
      "w" -> push_action(:move_up_start, socket)
      "s" -> push_action(:move_down_start, socket)
      "d" -> push_action(:move_right_start, socket)
      "a" -> push_action(:move_left_start, socket)
      "1" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 1}, socket)
      "2" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 2}, socket)
      "3" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 3}, socket)
      "4" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 4}, socket)
      " " -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 9}, socket)
      "p" ->
        GenServer.call(socket.assigns.battle, :pause)
        socket
      "Enter" -> handle_chat(socket)
      _ -> socket
    end

    {:noreply, socket}
  end

  def handle_event("key_down", "Enter", socket) do
    handle_chat(socket)
    |> noreply
  end

  def handle_event("key_down", "Backspace", %{assigns: %{typing: ""}} = socket) do
    {:noreply, socket}
  end

  def handle_event("key_down", "Backspace", socket) do
    msg = socket.assigns.typing
    assign(socket, :typing, String.slice(msg, 0, String.length(msg) - 1))
    |> noreply
  end

  def handle_event("key_down", "Escape", socket) do
    assign(socket, :typing, false)
    |> noreply
  end

  def handle_event("key_down", key, socket) do
    case String.length(key) do
      1 ->
        assign(socket, :typing, socket.assigns.typing <> key)
      _ ->
        socket
    end
    |> noreply
  end

  def handle_event("key_up", _, socket) do
    {:noreply, socket}
  end

  def handle_event("select_battle", %{"battle_pulldown" => battle_id}, socket) do
    assign(socket, :selected_battle, battle_id)
    |> noreply
  end

  def handle_event("select_fighter", fighter_type, socket) do
    assign(socket, :selected_fighter_type, fighter_type)
    |> assign(:fighter_information, ResultEx.unwrap!(SpaceBirds.MasterData.get_fighter_information(fighter_type)))
    |> noreply
  end

  def handle_event("confirm_fighter", _, socket) do
    assign(socket, :fighter_confirmed, true)
    |> assign(:battle_list, SpaceBirds.State.ArenaRegistry.list_all_joinable())
    |> assign(:error, nil)
    |> noreply
  end

  def handle_event("back_to_fighter_select", _, socket) do
    assign(socket, :fighter_confirmed, false)
    |> assign(:error, nil)
    |> noreply
  end

  def handle_event("button_click", event, socket) do
    push_action(:button_click, %Button{id: event}, socket)
    |> noreply
  end

  def handle_event("chat", %{"body" => body}, %{assigns: %{chat: {chat_id, _, _}}} = socket) do
    {:ok, {members, messages}} = ChatRoom.send(chat_id, body)

    assign(socket, :chat, {chat_id, members, messages})
    |> noreply
  end

  @impl(Phoenix.LiveView)
  def handle_info({:render, render_data, version}, socket) do
    assign(socket, :render_data, render_data)
    |> assign(:version, version)
    |> noreply
  end

  def handle_info({:chat, chat_id, {members, messages}}, %{assigns: %{chat: {joined_chat, _, _}}} = socket) when chat_id == joined_chat do
    assign(socket, :chat, {chat_id, members, messages})
    |> noreply
  end

  def handle_info({:chat, chat_id, _}, %{assigns: %{player: player}} = socket) do
    ChatRoom.leave(chat_id, player)
    {:noreply, socket}
  end

  @impl(Phoenix.LiveView)
  def terminate(_reason, socket) do
    OptionEx.return(socket.assigns.player)
    |> OptionEx.map(fn player ->
      Players.leave(player)
      unless player.battle_id == nil, do: GenServer.call(player.battle_id, {:leave, player})
    end)

    {chat_id, _, _} = socket.assigns.chat
    unless chat_id == nil, do: ChatRoom.leave(chat_id)
  end

  defp push_action(action_name, %{assigns: %{player: player, battle: battle_id}} = socket) do
    action = %Action{name: action_name, sender: {:player, player.id}}
    GenServer.cast(battle_id, {:push_action, action})
    socket
  end

  defp push_action(action_name, payload, %{assigns: %{player: player, battle: battle_id}} = socket) do
    action = %Action{name: action_name, sender: {:player, player.id}, payload: payload}
    GenServer.cast(battle_id, {:push_action, action})
    socket
  end

  defp handle_chat(%{assigns: %{typing: false}} = socket) do
    assign(socket, typing: "")
  end

  defp handle_chat(%{assigns: %{typing: ""}} = socket) do
    assign(socket, typing: false)
  end

  defp handle_chat(socket) do
    chat_id = elem(socket.assigns.chat, 0)
    {:ok, {members, messages}} = ChatRoom.send(chat_id, socket.assigns.typing)

    socket
    |> assign(typing: false)
    |> assign(chat: {chat_id, members, messages})
  end

  defp ok(state), do: {:ok, state}
  defp noreply(state), do: {:noreply, state}
end
