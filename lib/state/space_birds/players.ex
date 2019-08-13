defmodule SpaceBirds.State.Players do
  use GenServer

  @type player_id :: number

  @type battle_id :: number

  @type player :: %{
    id: player_id,
    battle_id: battle_id,
    pid: pid | nil,
    resolution: {number, number}
  }

  @type t :: {player_id, %{player_id => player}}

  defstruct id: 0,
    battle_id: 0,
    pid: nil,
    resolution: {1280, 960}

  def start_link(_) do
    GenServer.start_link(__MODULE__, {0, %{}}, name: __MODULE__)
  end

  def join(pid) do
    GenServer.call(__MODULE__, {:join, pid})
  end

  def find(id) do
    GenServer.call(__MODULE__, {:find, id})
  end

  def update(id, update) do
    GenServer.call(__MODULE__, {:update, id, update})
  end

  @impl(GenServer)
  def init({_, %{}} = state) do
    {:ok, state}
  end

  @impl(GenServer)
  def handle_call({:join, pid}, _, {last_id, players}) do
    id = last_id + 1
    player = %__MODULE__{id: id, pid: pid}
    players = Map.put(players, id, player)

    {:reply, {:ok, player}, {id, players}}
  end

  def handle_call({:find, id}, _, {_, players} = state) do
    case Map.fetch(players, id) do
      {:ok, player} -> {:reply, {:ok, player}, state}
      _ -> {:reply, {:error, :player_not_found}, state}
    end
  end

  def handle_call({:update, id, update}, _, {last_id, players} = state) do
    case Map.fetch(players, id) do
      {:ok, player} ->
        player = update.(player)
        {:reply, {:ok, player}, {last_id, Map.put(players, id, player)}}
      _ ->
        {:reply, {:error, :player_not_found}, state}
    end
  end

  def handle_call(:find_online, _, {_, players} = state) do
    connected_players = Enum.map(players, fn {_key, value} -> value end)
                        |> Enum.filter(fn
                          %{pid: nil} -> false
                          %{pid: pid} -> Process.alive?(pid)
                        end)

    {:reply, {:ok, connected_players}, state}
  end

  def handle_call(:inspect, _, state) do
    {:reply, state, state}
  end
end
