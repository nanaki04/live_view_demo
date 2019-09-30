defmodule SpaceBirds.State.Preloader do
  alias SpaceBirds.MasterData
  use GenServer, restart: :transient

  @batch_interval 1000

  @batch_size 100

  @type preloader_id :: GenServer.name

  @type t :: %{
    todo: [String.t],
    player_pid: pid | nil
  }

  defstruct todo: [],
    player_pid: nil

  def start_link([id: id, player_pid: pid]) do
    GenServer.start_link(__MODULE__, pid, name: id)
  end

  @impl(GenServer)
  def init(player_pid) do
    manifest = MasterData.get_manifest()
    Process.send_after(self(), :next_batch, 100)
    {:ok, %__MODULE__{todo: manifest, player_pid: player_pid}}
  end

  @impl(GenServer)
  def handle_info(:next_batch, %{player_pid: player_pid, todo: []}) do
    send(player_pid, :preload_done)

    {:stop, :normal, %{player_pid: player_pid, todo: []}}
  end

  def handle_info(:next_batch, %{player_pid: player_pid, todo: todo}) do
    {to_send, to_keep} = Enum.split(todo, @batch_size)
    send(player_pid, {:preload, to_send})
    Process.send_after(self(), :next_batch, @batch_interval)

    {:noreply, %__MODULE__{player_pid: player_pid, todo: to_keep}}
  end

end
