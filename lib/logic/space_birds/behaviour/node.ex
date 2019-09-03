defmodule SpaceBirds.Behaviour.Node do
  use SpaceBirds.Utility.MapAccess

  @type node_type :: String.t

  @type node_data :: term

  @type t :: %{
    id: number,
    type: node_type,
    node_data: node_data
  }

  defstruct id: 0,
    type: "undefined",
    node_data: %{}

  @callback init(t, id :: number, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  @callback select(t, Component.t, Arena.t) :: {:running, t} | :success | :failure
  @callback run(t, Component.t, Arena.t) :: {:ok, t, Arena.t} | {:error, String.t}
  @callback reset(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  @callback sync_running_node(node :: t, running_node :: t) :: t

  defmacro __using__(_opts) do
    quote do
      alias SpaceBirds.Behaviour.Node
      use SpaceBirds.Utility.MapAccess
      @behaviour SpaceBirds.Behaviour.Node

      @impl(SpaceBirds.Behaviour.Node)
      def init(node, id, _component, _arena) do
        {:ok, node}
      end

      @impl(SpaceBirds.Behaviour.Node)
      def select(node, _component, _arena) do
        {:running, node}
      end

      @impl(SpaceBirds.Behaviour.Node)
      def run(node, _component, arena) do
        {:ok, node, arena}
      end

      @impl(SpaceBirds.Behaviour.Node)
      def reset(node, _component, _arena) do
        {:ok, node}
      end

      @impl(SpaceBirds.Behaviour.Node)
      def sync_running_node(%{id: id} = node, %{id: running_node_id} = running_node) when id == running_node_id do
        running_node
      end

      def sync_running_node(node, running_node) do
        node
      end

      defoverridable [select: 3, run: 3, reset: 3, init: 4, sync_running_node: 2]
    end
  end

  @spec init(t, id :: number, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  def init(node, id, component, arena) do
    node = Map.put(node, :id, id)
    make_module_name(node)
    |> apply(:init, [node, id, component, arena])
  end

  @spec select(t, Component.t, Arena.t) :: {:running, t} | :success | :failure
  def select(node, component, arena) do
    running_node = component.component_data.running_node
    node = case {node, running_node} do
      {%{id: id}, %{id: running_node_id}} when id == running_node_id ->
        running_node
      {node, _} ->
        node
    end

    make_module_name(node)
    |> apply(:select, [node, component, arena])
  end

  @spec run(t, Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run(node, component, arena) do
    make_module_name(node)
    |> apply(:run, [node, component, arena])
  end

  @spec reset(t, Component.t, Arena.t) :: {:ok, t} | {:error, String.t}
  def reset(node, component, arena) do
    make_module_name(node)
    |> apply(:reset, [node, component, arena])
  end

  @spec sync_running_node(t, t) :: t
  def sync_running_node(node, running_node) do
    make_module_name(node)
    |> apply(:sync_running_node, [node, running_node])
  end

  defp make_module_name(node) do
    node.type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Behaviour, &1)).()
  end

end
