defmodule LiveViewDemoWeb.SpaceBirdsLive do
  use Phoenix.LiveView
  alias SpaceBirds.State.Players
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.Actions.SwapWeapon
  alias SpaceBirds.Actions.FireWeapon
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.MasterData

  def render(%{state: %{location: :main_menu}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "main_menu.html", assigns)
  end

  def render(%{state: %{location: :arena}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "arena.html", assigns)
  end

  def render(%{state: %{location: :result}} = assigns) do
    Phoenix.View.render(LiveViewDemoWeb.SpaceBirdsView, "result.html", assigns)
  end

  def mount(_session, socket) do
    socket
    |> assign(:state, %SpaceBirds.State.Application{})
    |> assign(:player, nil)
    |> assign(:render_data, [])
    |> assign(:battle_list, [])
    |> assign(:selected_battle, "new")
    |> assign(:fighter_types, ResultEx.unwrap!(MasterData.get_fighter_types()))
    |> assign(:selected_fighter_type, "hawk")
    |> ok
  end

  def handle_event("new_player", %{"player_name" => player_name}, socket) do
    {:ok, player} = Players.join(self(), player_name)

    assign(socket, player: player)
    |> assign(:battle_list, SpaceBirds.State.ArenaRegistry.list_all())
    |> noreply
  end

  def handle_event(
    "start_game",
    _,
    %{assigns: %{player: player, state: state, selected_battle: selected_battle, selected_fighter_type: fighter_type}} = socket
  ) do
    {:ok, id} = if selected_battle == "new" do
      SpaceBirds.State.ArenaSupervisor.start_child()
    else
      {:ok, {:via, Registry, {SpaceBirds.State.ArenaRegistry, selected_battle}}}
    end

    {:ok, player} = Players.update(player.id, fn player -> Map.put(player, :battle_id, id) end)
    GenServer.cast(id, {:join, player, fighter_type})

    socket
    |> assign(player: player)
    |> assign(battle: id)
    |> assign(state: Map.put(state, :location, :arena))
    |> noreply
  end

  def handle_event("grid", value, socket) do
    position = String.split(value, "_")
               |> Enum.map(&Integer.parse/1)
               |> Enum.map(&elem(&1, 0))
               |> Position.new

    push_action(:fire_weapon, %FireWeapon{grid_point: position}, socket)

    {:noreply, socket}
  end

  def handle_event("key_up", key, socket) do
    case key do
      "w" -> push_action(:move_up_stop, socket)
      "s" -> push_action(:move_down_stop, socket)
      "d" -> push_action(:move_right_stop, socket)
      "a" -> push_action(:move_left_stop, socket)
      _ -> :ok
    end

    {:noreply, socket}
  end

  def handle_event("key_down", key, socket) do
    case key do
      "w" -> push_action(:move_up_start, socket)
      "s" -> push_action(:move_down_start, socket)
      "d" -> push_action(:move_right_start, socket)
      "a" -> push_action(:move_left_start, socket)
      "1" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 1}, socket)
      "2" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 2}, socket)
      "3" -> push_action(:swap_weapon, %SwapWeapon{weapon_slot: 3}, socket)
      " " -> GenServer.call(socket.assigns.battle, :pause)
      _ -> :ok
    end

    {:noreply, socket}
  end

  def handle_event("select_battle", %{"battle_pulldown" => battle_id}, socket) do
    assign(socket, :selected_battle, battle_id)
    |> noreply
  end

  def handle_event("select_fighter", %{"fighter_pulldown" => fighter_type}, socket) do
    assign(socket, :selected_fighter_type, fighter_type)
    |> noreply
  end

  def handle_info({:render, render_data}, socket) do
    assign(socket, :render_data, render_data)
    |> noreply
  end

  defp push_action(action_name, %{assigns: %{player: player, battle: battle_id}}) do
    action = %Action{name: action_name, sender: {:player, player.id}}
    GenServer.cast(battle_id, {:push_action, action})
  end

  defp push_action(action_name, payload, %{assigns: %{player: player, battle: battle_id}}) do
    action = %Action{name: action_name, sender: {:player, player.id}, payload: payload}
    GenServer.cast(battle_id, {:push_action, action})
  end

  defp update_state(socket, updater) do
    assign(socket, :state, updater.(socket.assigns.state))
  end

  defp ok(state), do: {:ok, state}
  defp noreply(state), do: {:noreply, state}
  defp reply(state), do: {:reply, state, state}
end
