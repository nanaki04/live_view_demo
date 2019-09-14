defmodule SpaceBirds.State.BackPressureSystem do
  use GenServer, restart: :transient
  use SpaceBirds.Utility.MapAccess

  @type version :: number

  @type t :: %{
    pending: [version],
    max_pending: number
  }

  @type queue_result :: :ok | :refused

  defstruct pending: [],
    max_pending: 2

  def start_link([id: id]) do
    GenServer.start_link(__MODULE__, :ok, name: id)
  end

  @spec id(SpaceBirds.State.Players.player_id, SpaceBirds.State.Arena.id) :: GenServer.name
  def id(player_id, battle_id) do
    SpaceBirds.State.BackPressureSupervisor.via(player_id, battle_id)
  end

  @spec push(GenServer.name, version) :: queue_result
  def push(id, version) do
    GenServer.call(id, {:push, version})
  end

  @spec stop(GenServer.name) :: :ok
  def stop(id) do
    GenServer.call(id, :stop)
  end

  @spec confirm(GenServer.name, version) :: t
  def confirm(id, version) do
    GenServer.call(id, {:confirm, version})
  end

  @impl(GenServer)
  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  @impl(GenServer)
  def handle_call({:push, _version}, _, %{pending: pending, max_pending: max_pending} = queue)
    when length(pending) >= max_pending
  do
    {:reply, :refused, queue}
  end

  def handle_call({:push, version}, _, queue) do
    {:reply, :ok, %{queue | pending: [version | queue.pending]}}
  end

  def handle_call({:confirm, version}, _, queue) do
    Enum.reduce(queue.pending, [], fn
      pending_version, queue when pending_version > version -> [version | queue]
      _, queue -> queue
    end)
    |> Enum.reverse
    |> (&%{queue | pending: &1}).()
    |> (&{:reply, :ok, &1}).()
  end

  def handle_call(:stop, _, queue) do
    {:stop, :normal, :ok, queue}
  end

end
