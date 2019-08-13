defmodule SpaceBirds.Components.Component do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor

  @behaviour Access

  @type component_data :: term

  @type component_type :: atom

  @type t :: %{
    actor: Actor.t,
    type: component_type,
    component_data: component_data
  }

  defstruct actor: 0,
    type: :undefined,
    component_data: %{}

  @callback run(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      @behaviour SpaceBirds.Components.Component
      @behaviour Access

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

      defoverridable [run: 2]
    end
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
