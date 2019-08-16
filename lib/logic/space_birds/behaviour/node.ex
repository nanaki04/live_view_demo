defmodule SpaceBirds.Behaviour.Node do
  @behaviour Access

  @type node_type :: String.t

  @type node_data :: term

  @type t :: %{
    type: node_type,
    node_data: node_data
  }

  defstruct type: "undefined",
    node_data: %{}

  @callback select(t, Component.t, Arena.t) :: {:running, t} | :success | :failure
  @callback run(t, Component.t, Arena.t) :: {:ok, t, Arena.t} | {:error, String.t}
  @callback reset(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      @behaviour SpaceBirds.Behaviour.Node
      @behaviour Access

      @impl(SpaceBirds.Behaviour.Node)
      def select(node, component, arena) do
        :failure
      end

      @impl(SpaceBirds.Behaviour.Node)
      def run(node, _component, arena) do
        {:ok, node, arena}
      end

      @impl(SpaceBirds.Behaviour.Node)
      def reset(_node, _component, arena) do
        {:ok, arena}
      end

      @impl(Access)
      def fetch(data, key) do
        Map.fetch(data, key)
      end

      @impl(Access)
      def get_and_update(data, key, update) do
        Map.get_and_update(data, key, update)
      end

      @impl(Access)
      def pop(data, key) do
        Map.pop(data, key)
      end

      defoverridable [select: 3, run: 3, reset: 3]
    end
  end

  @spec select(t, Component.t, Arena.t) :: {:running, t} | :success | :failure
  def select(node, component, arena) do
    make_module_name(node)
    |> apply(:select, [node, component, arena])
  end

  @spec run(t, Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run(node, component, arena) do
    make_module_name(node)
    |> apply(:run, [node, component, arena])
  end

  @spec reset(t, Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def reset(node, component, arena) do
    make_module_name(node)
    |> apply(:reset, [node, component, arena])
  end

  defp make_module_name(node) do
    node.type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Behaviour, &1)).()
  end

  @impl(Access)
  def fetch(data, key) do
    Map.fetch(data, key)
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
