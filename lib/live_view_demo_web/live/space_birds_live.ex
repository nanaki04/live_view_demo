defmodule LiveViewDemoWeb.SpaceBirdsLive do
  use Phoenix.LiveView
  alias SpaceBirds.State.Players
  alias SpaceBirds.Actions.Action

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
    |> ok
  end

  def handle_event("new_player", _, socket) do
    {:ok, player} = Players.join(self())

    assign(socket, player: player)
    |> noreply
  end

  def handle_event("start_game", _, %{assigns: %{player: player, state: state}} = socket) do
    {:ok, id} = SpaceBirds.State.ArenaSupervisor.start_child()
    {:ok, player} = Players.update(player.id, fn player -> Map.put(player, :battle_id, id) end)
    GenServer.cast(id, {:join, player})

    socket
    |> assign(player: player)
    |> assign(battle: id)
    |> assign(state: Map.put(state, :location, :arena))
    |> noreply
  end

  def handle_event("grid", value, socket) do
    IO.inspect(value)
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
      _ -> :ok
    end

    {:noreply, socket}
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
