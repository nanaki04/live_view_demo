defmodule SpaceBirds.Components.Component do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor

  @behaviour Access

  @type component_data :: term

  @type component_type :: atom

  @type t :: %{
    actor: Actor.t,
    type: component_type,
    component_data: component_data,
    enabled?: boolean
  }

  defstruct actor: 0,
    type: :undefined,
    component_data: %{},
    enabled?: true

  @callback init(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback run(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      alias SpaceBirds.Components.Component
      @behaviour Component
      @behaviour Access

      @impl(Component)
      def init(component, arena) do
        Arena.update_component(arena, component, fn _ -> {:ok, component} end)
      end

      @impl(Component)
      def run(component, arena) do
        {:ok, arena}
      end

      @impl(Access)
      def fetch(component, key) do
        Map.fetch(component, key)
      end

      @impl(Access)
      def get_and_update(data, key, update) do
        Map.get_and_update(data, key, update)
      end

      @impl(Access)
      def pop(data, key) do
        Map.pop(data, key)
      end

      defoverridable [run: 2, init: 2]
    end
  end

  @spec init(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def init(component, arena) do
    component = Map.merge(%__MODULE__{}, component)
    component.type
    |> Atom.to_string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Components, &1)).()
    |> apply(:init, [component, arena])
  end

  @spec put_in_data(t, term, term) :: t
  def put_in_data(component, key, value) do
    Map.update(component, :component_data, %{key => value}, fn component_data ->
      Map.put(component_data, key, value)
    end)
  end

  @impl(Access)
  def fetch(component, key) do
    Map.fetch(component, key)
  end

  @impl(Access)
  def get_and_update(data, key, update) do
    Map.get_and_update(data, key, update)
  end

  @impl(Access)
  def pop(data, key) do
    Map.pop(data, key)
  end

end
