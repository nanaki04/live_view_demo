defmodule SpaceBirds.BuffDebuff.BuffDebuff do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.VisualEffectStack
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.BuffDebuff.DiminishingReturns
  use SpaceBirds.Utility.MapAccess

  @type buff_debuff_type :: String.t

  @type effect_type :: String.t

  @type t :: %{
    id: number,
    type: buff_debuff_type,
    time: number,
    time_remaining: number,
    effect_type: effect_type,
    icon_path: String.t,
    buff_data: %{},
    debuff_data: %{},
    diminishing_returns_cooldown: number
  }

  defstruct id: 0,
    type: "",
    time: 0,
    time_remaining: 0,
    effect_type: "none",
    icon_path: "none",
    buff_data: %{},
    debuff_data: %{},
    diminishing_returns_cooldown: 0

  @callback run(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_apply(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_remove(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback affect_stats(t, stats :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  @callback apply_diminishing_returns(t, level :: number) :: {:ok, t} | {:error, String}

  defmacro __using__(_opts) do
    quote do
      alias SpaceBirds.BuffDebuff.BuffDebuff
      use SpaceBirds.Utility.MapAccess
      @behaviour BuffDebuff

      @impl(BuffDebuff)
      def run(buff_debuff, buff_debuff_stack, arena) do
        evaluate_expiration(buff_debuff, buff_debuff_stack, arena)
      end

      @impl(BuffDebuff)
      def on_apply(buff_debuff, buff_debuff_stack, arena) do
        apply_default(buff_debuff, buff_debuff_stack, arena)
      end

      @impl(BuffDebuff)
      def affect_stats(buff_debuff, stats, arena) do
        {:ok, stats}
      end

      @impl(BuffDebuff)
      def on_remove(buff_debuff, buff_debuff_stack, arena) do
        remove_from_stack(buff_debuff, buff_debuff_stack, arena)
        |> ResultEx.bind(&remove_visual_effect(buff_debuff, buff_debuff_stack, &1))
      end

      @impl(BuffDebuff)
      def apply_diminishing_returns(buff_debuff, _) do
        {:ok, buff_debuff}
      end

      defp apply_default(buff_debuff, buff_debuff_stack, arena) do
        {:ok, buff_debuff} = put_in(buff_debuff.time_remaining, buff_debuff.time)
                             |> calculate_diminishing_returns(buff_debuff_stack, arena)

        {:ok, buff_debuff_stack} = increase_diminishing_returns(buff_debuff, buff_debuff_stack)

        add_to_stack(buff_debuff, buff_debuff_stack, arena)
        |> ResultEx.bind(&play_visual_effect(buff_debuff, buff_debuff_stack, &1))
      end

      defp add_to_stack(buff_debuff, buff_debuff_stack) do
        id = buff_debuff_stack.component_data.buff_debuffs.last_id + 1
        buff_debuff_stack = update_in(buff_debuff_stack.component_data.buff_debuffs, fn buff_debuffs ->
          buff_debuffs
          |> Map.put(:last_id, id)
          |> Map.put(id, Map.put(buff_debuff, :id, id))
        end)

        {:ok, buff_debuff_stack}
      end

      defp add_to_stack(buff_debuff, buff_debuff_stack, arena) do
        Arena.update_component(arena, buff_debuff_stack, fn stack ->
          add_to_stack(buff_debuff, buff_debuff_stack)
        end)
      end

      defp remove_from_stack(buff_debuff, buff_debuff_stack, arena) do
        Arena.update_component(arena, buff_debuff_stack, fn stack ->
          stack = update_in(stack.component_data.buff_debuffs, & Map.delete(&1, buff_debuff.id))

          {:ok, stack}
        end)
      end

      defp update_in_stack(buff_debuff, buff_debuff_stack, arena) do
        Arena.update_component(arena, buff_debuff_stack, fn stack ->
          update_in(stack.component_data.buff_debuffs, fn buff_debuffs ->
            Map.put(buff_debuffs, buff_debuff.id, buff_debuff)
          end)
          |> ResultEx.return
        end)
      end

      defp evaluate_expiration(buff_debuff, buff_debuff_stack, arena) do
        buff_debuff = update_in(buff_debuff.time_remaining, & max(0, &1 - arena.delta_time * 1000))
        {:ok, arena} = update_in_stack(buff_debuff, buff_debuff_stack, arena)

        if buff_debuff.time_remaining <= 0 do
          on_remove(buff_debuff, buff_debuff_stack, arena)
        else
          {:ok, arena}
        end
      end

      defp calculate_diminishing_returns(buff_debuff, buff_debuff_stack, arena) do
        actor = buff_debuff_stack.actor

        with {:ok, stats} <- Components.fetch(arena.components, :stats, actor),
             {:some, level} <- Stats.find_diminishing_returns(stats, buff_debuff.type, arena)
        do
          apply_diminishing_returns(buff_debuff, level)
        else
          _ ->
            {:ok, buff_debuff}
        end
      end

      defp increase_diminishing_returns(%{diminishing_returns_cooldown: 0}, buff_debuff_stack) do
        {:ok, buff_debuff_stack}
      end

      defp increase_diminishing_returns(buff_debuff, buff_debuff_stack) do
        DiminishingReturns.new(buff_debuff.type, buff_debuff.diminishing_returns_cooldown)
        |> add_to_stack(buff_debuff_stack)
      end

      defp play_visual_effect(%{effect_type: "none"}, _, arena) do
        {:ok, arena}
      end

      defp play_visual_effect(%{effect_type: ""}, _, arena) do
        {:ok, arena}
      end

      defp play_visual_effect(buff_debuff, buff_debuff_stack, arena) do
        actor = buff_debuff_stack.actor
        effect_type = buff_debuff.effect_type

        with {:ok, visual_effect_stack} <- Components.fetch(arena.components, :visual_effect_stack, actor),
             {:ok, arena} <- VisualEffectStack.add_visual_effect(visual_effect_stack, effect_type, arena),
             {:ok, visual_effect_stack} <- Components.fetch(arena.components, :visual_effect_stack, actor),
             {:some, effect_id} <- VisualEffectStack.find(visual_effect_stack, effect_type)
        do
          Arena.update_component(arena, :follow, effect_id, fn follow ->
            {:ok, put_in(follow.component_data.target, actor)}
          end)
        else
          _ ->
            {:ok, arena}
        end
      end

      defp remove_visual_effect(%{effect_type: "none"}, _, arena) do
        {:ok, arena}
      end

      defp remove_visual_effect(%{effect_type: ""}, _, arena) do
        {:ok, arena}
      end

      defp remove_visual_effect(buff_debuff, buff_debuff_stack, arena) do
        actor = buff_debuff_stack.actor
        effect_type = buff_debuff.effect_type

        with count when count <= 1 <- BuffDebuffStack.count_by_type(buff_debuff_stack, buff_debuff.type),
             {:ok, visual_effect_stack} <- Components.fetch(arena.components, :visual_effect_stack, actor)
        do
          VisualEffectStack.remove_visual_effect(visual_effect_stack, effect_type, arena)
        else
          _ ->
            {:ok, arena}
        end
      end

      defoverridable [run: 3, on_apply: 3, on_remove: 3, affect_stats: 3, apply_diminishing_returns: 2]
    end
  end

  @spec run(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run(buff_debuff, buff_debuff_stack, arena) do
    get_module_name(buff_debuff)
    |> apply(:run, [buff_debuff, buff_debuff_stack, arena])
  end

  @spec on_apply(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def on_apply(buff_debuff, buff_debuff_stack, arena) do
    get_module_name(buff_debuff)
    |> apply(:on_apply, [buff_debuff, buff_debuff_stack, arena])
  end

  @spec affect_stats(t, stats :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  def affect_stats(buff_debuff, stats, arena) do
    get_module_name(buff_debuff)
    |> apply(:affect_stats, [buff_debuff, stats, arena])
  end

  @spec on_remove(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def on_remove(buff_debuff, buff_debuff_stack, arena) do
    get_module_name(buff_debuff)
    |> apply(:on_remove, [buff_debuff, buff_debuff_stack, arena])
  end

  defp get_module_name(buff_debuff) do
    buff_debuff.type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.BuffDebuff, &1)).()
  end
end
