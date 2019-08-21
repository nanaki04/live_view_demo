defmodule SpaceBirds.BuffDebuff.BuffDebuff do
  alias SpaceBirds.State.Arena
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
    debuff_data: %{}
  }

  defstruct id: 0,
    type: "",
    time_remaining: 0,
    effect_type: "none",
    icon_path: "none",
    buff_data: %{},
    debuff_data: %{}

  @callback run(t, buff_debuff_stack :: Componnet.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_apply(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_remove(t, buff_debuff_stack :: Component.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback affect_stats(t, stats :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}

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
        buff_debuff = put_in(buff_debuff.time_remaining, buff_debuff.time)
        add_to_stack(buff_debuff, buff_debuff_stack, arena)
      end

      @impl(BuffDebuff)
      def affect_stats(buff_debuff, stats, arena) do
        {:ok, stats}
      end

      @impl(BuffDebuff)
      def on_remove(buff_debuff, buff_debuff_stack, arena) do
        remove_from_stack(buff_debuff, buff_debuff_stack, arena)
      end

      defp add_to_stack(buff_debuff, buff_debuff_stack, arena) do
        Arena.update_component(arena, buff_debuff_stack, fn stack ->
          id = stack.component_data.buff_debuffs.last_id + 1
          stack = update_in(stack.component_data.buff_debuffs, fn buff_debuffs ->
            buff_debuffs
            |> Map.put(:last_id, id)
            |> Map.put(id, Map.put(buff_debuff, :id, id))
          end)

          {:ok, stack}
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

      defoverridable [run: 3, on_apply: 3, on_remove: 3, affect_stats: 3]
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

  defp get_module_name(buff_debuff) do
    buff_debuff.type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.BuffDebuff, &1)).()
  end
end
