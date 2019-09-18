defmodule SpaceBirds.Components.Components do
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Components.Component

  @type component_list :: %{Actor.t => Component}

  @type t :: %{
    atom => component_list
  }

  @spec add_component(t, Component.t) :: ResultEx.t
  def add_component(components, component) do
    Map.update(components, component.type, Map.put(%{}, component.actor, component), fn component_list ->
      Map.put(component_list, component.actor, component)
    end)
    |> ResultEx.return
  end

  @spec remove_component(t, Component.t) :: ResultEx.t
  def remove_component(components, %{type: type, actor: actor}) do
    Map.update(components, type, %{}, fn component_list ->
      Map.delete(component_list, actor)
    end)
    |> ResultEx.return
  end

  @spec remove_component(t, Component.component_type, Actor.t) :: ResultEx.t
  def remove_component(components, component_type, actor) do
    Map.update(components, component_type, %{}, fn component_list ->
      Map.delete(component_list, actor)
    end)
    |> ResultEx.return
  end

  @spec remove_components(t, Actor.t) :: ResultEx.t
  def remove_components(components, actor) do
    Enum.map(components, fn {component_type, component_list} ->
      {component_type, Map.delete(component_list, actor)}
    end)
    |> Enum.into(%{})
    |> ResultEx.return
  end

  @spec map(t, (Component.t -> {:ok, Component.t} | {:error, String.t})) :: ResultEx.t
  def map(components, iterator) do
    Map.keys(components)
    |> sort()
    |> Enum.reduce({:ok, components}, fn
      component_type, {:ok, components} ->
        map(components, component_type, iterator)
      _, error ->
        error
    end)
  end

  @spec map(t, Component.component_type, (Component.t -> {:ok, Component.t} | {:error, String.t})) :: ResultEx.t
  def map(components, component_type, iterator) do
    update_list(components, component_type, fn component_list ->
      Enum.map(component_list, fn {actor, component} -> {actor, iterator.(component)} end)
      |> Enum.into(%{})
      |> ResultEx.flatten_enum
    end)
  end

  @spec sort([Component.component_type]) :: [Component.component_type]
  defp sort(component_types) do
    Enum.sort(component_types, fn # TODO decide correct update order
      :movement_controller, _ -> true
      _, :movement_controller -> false
      :transform, _ -> true
      _, :transform -> false
      :follow, _ -> true
      _, :follow -> false
      :camera, _ -> true
      _, :camera -> false
      :buff_debuff_stack, _ -> true
      _, :buff_debuff_stack -> false
      _, _ -> true
    end)
  end

  @spec reduce(t, Component.component_type, (Component.t, term -> term), ResultEx.t) :: ResultEx.t
  def reduce(components, component_type, initial_value, iterator) do
    case Map.fetch(components, component_type) do
      {:ok, component_list} ->
        Enum.reduce(component_list, {:ok, initial_value}, fn
          {_, component}, {:ok, acc} ->
            iterator.(component, acc)
          _, error ->
            error
        end)
      :error ->
        {:ok, initial_value}
    end
  end

  def reduce(components, initial_value, iterator) do
    Map.keys(components)
    |> sort()
    |> Enum.reduce({:ok, initial_value}, fn
      component_type, {:ok, value} ->
        reduce(components, component_type, value, iterator)
      _, error ->
        error
    end)
  end

  @spec fetch(t, Component.component_type) :: ResultEx.t
  def fetch(components, component_type) do
    case Map.fetch(components, component_type) do
      :error -> {:ok, %{}}
      ok -> ok
    end
  end

  @spec fetch(t, Component.component_type, Actor.t) :: ResultEx.t
  def fetch(components, component_type, actor) do
    case Map.fetch(components, component_type) do
      :error ->
        {:error, "no such component type: #{component_type}"}
      {:ok, component_list} ->
        case Map.fetch(component_list, actor) do
          :error ->
            {:error, "actor '#{actor}' has no component '#{component_type}'"}
          ok ->
            ok
        end
    end
  end

  @spec filter_by_actor(t, Actor.t) :: [Component.t]
  def filter_by_actor(components, actor) do
    Enum.flat_map(components, fn {_, component_list} ->
      Enum.filter(component_list, fn
        {^actor, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {_, component} -> component end)
    end)
  end

  @spec update(t, Component.component_type, Actor.t, (Component.t -> ResultEx.t)) :: ResultEx.t
  def update(components, component_type, actor, updater) do
    update_list(components, component_type, fn component_list ->
      case Map.fetch(component_list, actor) do
        {:ok, component} ->
          updater.(component)
          |> ResultEx.map(fn component -> Map.put(component_list, actor, component) end)
        :error ->
          {:ok, component_list}
      end
    end)
  end

  @spec update_list(t, Component.component_type, (component_list -> ResultEx.t)) :: ResultEx.t
  defp update_list(components, component_type, updater) do
    case Map.fetch(components, component_type) do
      {:ok, component_list} ->
        updater.(component_list)
      :error ->
        {:ok, %{}}
    end
    |> ResultEx.map(fn component_list -> Map.put(components, component_type, component_list) end)
  end

end
