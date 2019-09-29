defmodule SpaceBirds.State.Arena do
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Components.PlayerSpawner
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Players
  alias SpaceBirds.State.BackPressureSystem
  alias SpaceBirds.State.BackPressureSupervisor
  alias SpaceBirds.Actions.Action
  alias SpaceBirds.MasterData
  # MEMO the restart strategy is transient, but the arena will be shut down normal anyway on the first tick of the recovered state,
  # since all client references will be booted from the state when an error occurs
  # this could be improved by either having the players rejoin the recovered process
  # and if we want to get really crazy, have a backup genserver running to recover the state entirely on restart
  use GenServer, restart: :transient

  @type id :: GenServer.name

  @type t :: %{
    id: GenServer.name,
    components: Components.t,
    last_actor_id: Actor.t,
    players: [Players.player],
    actions: [term],
    frame_time: number,
    delta_time: number,
    paused: boolean,
    version: number,
    time_left: number
  }

  defstruct id: {:via, Registry, {SpaceBirds.State.ArenaRegistry, ""}},
    components: %{},
    last_actor_id: 0,
    players: [],
    actions: [],
    frame_time: 0,
    delta_time: 0,
    paused: false,
    version: 0,
    time_left: 600000,
    fps: 30

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

    next_id = arena.last_actor_id + 1
    {:ok, prototypes} = MasterData.get_prototypes(arena_type, next_id)
    {:ok, arena} = Enum.reduce(prototypes, {:ok, arena}, fn
      prototype, {:ok, arena} -> add_actor(arena, prototype)
    end)

    next_id = arena.last_actor_id + 1
    {:ok, spawners} = MasterData.get_spawners(arena_type, next_id)
    {:ok, arena} = Enum.reduce(spawners, {:ok, arena}, fn
      spawner, {:ok, arena} -> add_actor(arena, spawner)
    end)

    Process.send_after(self(), :tick, 100)

    {:ok, %{arena | id: id}}
  end

  @impl(GenServer)
  def handle_call(:inspect, _, state) do
    {:reply, state, state}
  end

  def handle_call(:pause, _, state) do
    state = Map.put(state, :paused, !state.paused)
    if !state.paused do
      Process.send_after(self(), :tick, max(round(1000 / state.fps) - (System.system_time(:millisecond) - state.frame_time), 0))
    end
    {:reply, state, state}
  end

  def handle_call(:fps_down, _, arena) do
    arena = Map.update(arena, :fps, 30, &max(1, &1 - 1))
    {:reply, arena.fps, arena}
  end

  def handle_call(:fps_up, _, arena) do
    arena = Map.update(arena, :fps, 30, &min(30, &1 + 1))
    {:reply, arena.fps, arena}
  end

  def handle_call({:leave, player}, _, arena) do
    BackPressureSystem.id(player.id, arena.id)
    |> BackPressureSystem.stop

    actor = find_player_actor(arena, player.id)
    {:ok, arena} = remove_actor(arena, actor)

    arena = update_in(arena.players, fn players ->
      Enum.filter(players, fn joined_player ->
        joined_player.id != player.id
      end)
    end)

    if length(arena.players) <= 0 do
      {:stop, :normal, :ok, arena}
    else
      {:reply, :ok, arena}
    end
  end

  @impl(GenServer)
  def handle_cast({:join, player, fighter_type}, arena) do
    fighter_id = arena.last_actor_id + 1
    {:ok, fighter} = MasterData.get_player_fighter(fighter_type, fighter_id, player)
    {:ok, camera} = MasterData.get_camera(player.id, fighter_id)
    {:ok, arena} = add_actor(arena, fighter)
    {:ok, arena} = add_actor(arena, camera)
    {:ok, arena} = PlayerSpawner.set_spawn_position(fighter_id, arena)

    arena = Map.update(arena, :players, [], fn players -> [player | players] end)

    {:ok, _} = BackPressureSupervisor.start_child(player.id, arena.id)

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
    arena = update_in(arena.version, &(&1 + 1))

    {:ok, arena} = if arena.time_left > 0 do
      Components.reduce(arena.components, arena, fn
        %{enabled?: false}, arena ->
          {:ok, arena}
        component, arena ->
          module_name = Atom.to_string(component.type)
                        |> String.split("_")
                        |> Enum.map(&String.capitalize/1)
                        |> Enum.join

          full_module_name = Module.concat(SpaceBirds.Components, module_name)

          apply(full_module_name, :run, [component, arena])
      end)
    else
      {:ok, arena}
    end

    {:ok, cameras} = Components.fetch(arena.components, :camera)
    online_players = Enum.filter(arena.players, fn player -> player.pid != nil end)
                     |> Enum.filter(fn player -> Process.alive?(player.pid) end)

    available_players = Enum.filter(online_players, fn player ->
                          BackPressureSystem.id(player.id, arena.id)
                          |> BackPressureSystem.push(arena.version)
                          |> (fn
                            :ok -> true
                            :refused -> false
                          end).()
                        end)

    Enum.each(available_players, fn player ->
      {_, camera} = Enum.find(cameras, fn {_, camera} ->
        camera.component_data.owner == player.id
      end)

      send(player.pid, {:render, camera.component_data.render_data, arena.version})
    end)

    {:ok, arena} = SpaceBirds.Collision.Simulation.simulate(arena)

    arena = if length(online_players) > 1 do
      update_in(arena.time_left, &(&1 - arena.delta_time * 1000))
    else
      arena
    end

    arena = Map.put(arena, :actions, [])

    if !arena.paused do
      Process.send_after(self(), :tick, max(round(1000 / arena.fps) - (System.system_time(:millisecond) - arena.frame_time), 0))
    end

    if length(online_players) > 0 do
      {:noreply, arena}
    else
      {:stop, :normal, arena}
    end
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

  @spec find_player_by_actor(t, Actor.t) :: {:ok, Players.player_id} | {:error, String.t}
  def find_player_by_actor(arena, actor) do
    Components.fetch(arena.components, :ui)
    |> ResultEx.map(fn ui_list ->
      Enum.find(ui_list, fn
        {_, %{actor: ^actor}} -> true
        _ -> false
      end)
    end)
    |> ResultEx.bind(fn
      {_, %{component_data: %{owner: player_id}}} -> {:ok, player_id}
      nil -> {:error, "No player found for actor #{actor}!"}
    end)
  end
end
