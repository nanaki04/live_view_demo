defmodule SpaceBirds.State.ArenaSupervisor do
  use DynamicSupervisor

  @vsn "0"

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child() do
    gen_id()
    |> create_arena()
  end

  @impl(DynamicSupervisor)
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp gen_id() do
    {:global, Ecto.UUID.generate()}
  end

  defp create_arena(id) do
    if GenServer.whereis(id) != nil do
      create_arena(gen_id())
    else
      {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {SpaceBirds.State.Arena, id: id})
      {:ok, id}
    end
  end

end
