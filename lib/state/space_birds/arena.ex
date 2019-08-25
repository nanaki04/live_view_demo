defmodule SpaceBirds.State.Arena do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Players
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.MasterData
  use GenServer

  @fps 30

  @type t :: %{
    id: GenServer.name,
    components: Components.t,
    last_actor_id: Actor.t,
    players: [Players.player],
    actions: [term],
    frame_time: number,
    delta_time: number,
    paused: boolean
  }

  defstruct id: {:via, Registry, {SpaceBirds.State.ArenaRegistry, ""}},
    components: %{},
    last_actor_id: 0,
    players: [],
    actions: [],
    frame_time: 0,
    delta_time: 0,
    paused: false

  def start_link([id: id]) do
    GenServer.start_link(__MODULE__, {id, :standard}, name: id)
  end

  @spec update_components(t, (Components.t -> ResultEx.t)) :: ResultEx.t
  def update_components(arena, updater) do
    {:ok, components} = Map.fetch(arena, :components)
    case updater.(components) do
      {:ok, components} ->
        {:ok, Map.put(arena, :components, components)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec update_component(t, Component.t, (Component.t -> ResultEx.t)) :: ResultEx.t
  def update_component(arena, %{type: component_type, actor: actor}, updater) do
    update_component(arena, component_type, actor, updater)
  end

  @spec update_component(t, Component.component_type, Actor.t, (Component.t -> ResultEx.t)) :: ResultEx.t
  def update_component(arena, component_type, actor, updater) do
    update_components(arena, fn components ->
      Components.update(components, component_type, actor, updater)
    end)
  end

  @spec add_component(t, Component.t) :: ResultEx.t
  def add_component(arena, component) do
    {:ok, arena} = update_components(arena, fn components ->
      Components.add_component(components, component)
    end)
    {:ok, component} = Components.fetch(arena.components, component.type, component.actor)
    Component.init(component, arena)
  end

  @spec find_player(t, Players.player_id) :: ResultEx.t
  def find_player(arena, player_id) do
    case Enum.find(arena.players, fn player -> player.id == player_id end) do
      nil -> {:error, "Player with id #{player_id} not in the arena"}
      player -> {:ok, player}
    end
  end

  @impl(GenServer)
  def init({id, arena_type}) do
    {:ok, arena} = MasterData.get_map(arena_type)
    {:ok, background} = MasterData.get_background(arena_type)
    {:ok, arena} = add_actor(arena, background)

    Process.send_after(self(), :tick, 1000)

    {:ok, %{arena | id: id}}
  end

  @impl(GenServer)
  def handle_call(:inspect, _, state) do
    {:reply, state, state}
  end

  def handle_call(:pause, _, state) do
    state = Map.put(state, :paused, !state.paused)
    if !state.paused do
      Process.send_after(self(), :tick, max(round(1000 / @fps) - (System.system_time(:millisecond) - state.frame_time), 0))
    end
    {:reply, state, state}
  end

  @impl(GenServer)
  def handle_cast({:join, player, fighter_type}, arena) do
    fighter_id = arena.last_actor_id + 1
    {:ok, fighter} = MasterData.get_player_fighter(fighter_type, fighter_id, player.id)
    {:ok, camera} = MasterData.get_camera(player.id, fighter_id)
    {:ok, arena} = add_actor(arena, fighter)
    {:ok, arena} = add_actor(arena, camera)

    arena = Map.update(arena, :players, [], fn players -> [player | players] end)

    {:noreply, arena}
  end

  def handle_cast({:push_action, action}, arena) do
    {:ok, action} = Action.init(action, arena)
    arena = Map.put(arena, :actions, [action | arena.actions])

    {:noreply, arena}
  end

  @impl(GenServer)
  def handle_info(:tick, arena) do
    arena = update_delta_time(arena)

    {:ok, arena} = Components.reduce(arena.components, arena, fn component, arena ->
      module_name = Atom.to_string(component.type)
                    |> String.split("_")
                    |> Enum.map(&String.capitalize/1)
                    |> Enum.join

      full_module_name = Module.concat(SpaceBirds.Components, module_name)

      apply(full_module_name, :run, [component, arena])
    end)

    {:ok, cameras} = Components.fetch(arena.components, :camera)
    online_players = Enum.filter(arena.players, fn player -> player.pid != nil end)
                     |> Enum.filter(fn player -> Process.alive?(player.pid) end)

    Enum.each(online_players, fn player ->
      {_, camera} = Enum.find(cameras, fn {_, camera} ->
        camera.component_data.owner == player.id
      end)

      send(player.pid, {:render, camera.component_data.render_data})
    end)

    {:ok, arena} = SpaceBirds.Collision.Simulation.simulate(arena)

    arena = Map.put(arena, :actions, [])

    if !arena.paused do
      Process.send_after(self(), :tick, max(round(1000 / @fps) - (System.system_time(:millisecond) - arena.frame_time), 0))
    end

    {:noreply, arena}
  end

  defp update_delta_time(%{frame_time: 0} = arena) do
    Map.put(arena, :delta_time, 0)
    |> Map.put(:frame_time, System.system_time(:millisecond))
  end

  defp update_delta_time(arena) do
    now = System.system_time(:millisecond)
    diff = now - arena.frame_time

    dt = case diff do
      0 -> 0
      diff -> diff / 1000
    end

    Map.put(arena, :delta_time, dt)
    |> Map.put(:frame_time, now)
  end

  @spec add_actor(t, %{term => term}) :: {:ok, t} | {:error, String.t}
  def add_actor(arena, actor) do
    id = arena.last_actor_id + 1
    arena = %{arena | last_actor_id: id}
    Enum.reduce(actor, {:ok, arena}, fn
      {_component_type, component}, {:ok, arena} ->
        component = component
                    |> Map.put(:actor, id)
                    |> Map.update(:type, :undefined, fn
                      type when is_binary(type) -> String.to_atom(type)
                      type -> type
                    end)

        add_component(arena, component)
      _, error ->
        error
    end)
  end

  @spec remove_actor(t, Actor.t) :: {:ok, t} | {:error, String.t}
  def remove_actor(arena, actor) do
    #    Components.filter_by_actor(arena.components, actor)
    #    |> Enum.reduce({:ok, arena}, fn
    #      component, {:ok, arena} -> Component.destroy(component, arena)
    #      _, error -> error
    #    end)
    update_components(arena, fn components ->
      Components.remove_components(components, actor)
    end)
  end

  @spec remove_component(t, Component.t) :: {:ok, t} | {:error, String.t}
  def remove_component(arena, component) do
    update_components(arena, & Components.remove_component(&1, component))
  end

  @spec remove_component(t, Component.component_type, Actor.t) :: {:ok, t} | {:error, String.t}
  def remove_component(arena, component_type, actor) do
    update_components(arena, & Components.remove_component(&1, component_type, actor))
  end

  @spec find_player_actor(t, Players.player_id) :: {:ok, Actor.t} | {:error, String.t}
  def find_player_actor(arena, player_id) do
    Components.fetch(arena.components, :ui)
    |> ResultEx.map(fn ui_list ->
      Enum.find(ui_list, fn
        {_, %{component_data: %{owner: ^player_id}}} -> true 
        _ -> false
      end)
    end)
    |> ResultEx.bind(fn
      {actor, _} -> {:ok, actor}
      nil -> {:error, "No actor found for player #{player_id}!"}
    end)
  end
end
