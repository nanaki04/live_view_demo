defmodule SpaceBirds.State.ArenaBackup do
  use GenServer, restart: :transient

  @backup_lifetime 30000

  def start_link([id: id, arena: arena]) do
    GenServer.start_link(__MODULE__, arena, name: id)
  end

  @impl(GenServer)
  def init(arena) do
    Process.send_after(self(), :shutdown, @backup_lifetime)
    {:ok, arena}
  end

  @impl(GenServer)
  def handle_call(:retrieve, _, arena) do
    {:stop, :normal, arena, arena}
  end

  @impl(GenServer)
  def handle_info(:shutdown, arena) do
    {:stop, :normal, arena}
  end

end
