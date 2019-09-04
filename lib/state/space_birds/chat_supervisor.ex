defmodule SpaceBirds.State.ChatSupervisor do
  use DynamicSupervisor

  @vsn "0"

  def start_link(_) do
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    {:ok, _} = start_child("global")
    {:ok, pid}
  end

  def start_child({:via, Registry, {SpaceBirds.State.ChatRegistry, _}} = id) do
    create_chat_room(id)
  end

  def start_child(id) do
    id
    |> via
    |> create_chat_room
  end

  @impl(DynamicSupervisor)
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec via(String.t) :: GenServer.name
  def via(id) do
    {:via, Registry, {SpaceBirds.State.ChatRegistry, id}}
  end

  @spec global_chat_id() :: GenServer.name
  def global_chat_id() do
    via("global")
  end

  defp create_chat_room(id) do
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {SpaceBirds.State.ChatRoom, id: id})
    {:ok, id}
  end

end
