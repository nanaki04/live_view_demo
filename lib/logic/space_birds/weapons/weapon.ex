defmodule SpaceBirds.Weapons.Weapon do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Arsenal
  alias SpaceBirds.Components.Stats
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.BuffDebuff.Channel
  use SpaceBirds.Utility.MapAccess

  @type weapon_data :: term

  @type weapon_slot :: number

  @type weapon_name :: String.t

  @type t :: %{
    actor: Actor.t,
    weapon_slot: weapon_slot,
    weapon_data: weapon_data,
    weapon_name: weapon_name,
    icon: String.t,
    cooldown: number,
    cooldown_remaining: number,
    energy_cost: number,
    instant?: boolean,
    channel_effect_path: String.t,
    channeling: boolean,
    channel_time: number,
    channel_time_remaining: number
  }

  defstruct actor: 0,
    weapon_slot: 0,
    weapon_data: %{},
    weapon_name: :undefined,
    icon: "white",
    cooldown: 500,
    cooldown_remaining: 0,
    energy_cost: 0,
    instant?: false,
    channel_effect_path: "none",
    channeling: false,
    channel_time: 0,
    channel_time_remaining: 0

  @callback fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_cooldown(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback run(t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_channel(t, channel_time_remaining :: number, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback on_hit(t, damage :: Component.t, Arena.t) :: {:ok, Component.t} | {:error, String.t}

  @default_channel_effect "none"

  defmacro __using__(_opts) do
    quote do
      use SpaceBirds.Utility.MapAccess
      alias SpaceBirds.Weapons.Weapon
      @behaviour Weapon

      @impl(Weapon)
      def fire(_weapon, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Weapon)
      def on_cooldown(_weapon, _target_position, arena) do
        {:ok, arena}
      end

      @impl(Weapon)
      def run(weapon, arena) do
        {:ok, {weapon, arena}} = cool_down(weapon, arena)
        channel(weapon, arena)
      end

      @impl(Weapon)
      def on_hit(_, damage, _) do
        {:ok, damage}
      end

      @impl(Weapon)
      def on_channel(_weapon, _channel_time_remaining, arena) do
        {:ok, arena}
      end

      defp cool_down(weapon, arena) do
        weapon = update_in(weapon.cooldown_remaining, & max(0, &1 - arena.delta_time * 1000))
        {:ok, arena} = update_weapon(weapon, arena)
        {:ok, {weapon, arena}}
      end


      defp remove_channel(weapon, arena) do
        with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
        do
          BuffDebuffStack.remove_by_type(buff_debuff_stack, "channel", arena)
        else
          _ ->
            {:ok, arena}
        end
      end

      defp channel(%{channeling: false}, arena) do
        {:ok, arena}
      end

      defp channel(weapon, arena) do
        if channeling?(weapon, arena) do
          weapon = update_channel_time(weapon, arena)
          {:ok, arena} = update_weapon(weapon, arena)
          on_channel(weapon, weapon.channel_time_remaining, arena)
        else
          weapon = put_in(weapon.channeling, false)
          {:ok, arena} = update_weapon(weapon, arena)
          remove_channel(weapon, arena)
        end
      end

      defp channeling?(%{weapon_data: %{channeling: false}}, arena) do
        false
      end

      defp channeling?(weapon, arena) do
        with {:ok, stats} <- Stats.get_readonly(arena, weapon.actor),
             false <- MapSet.member?(stats.component_data.status, :stunned),
             true <- MapSet.member?(stats.component_data.status, {:channeling, weapon.weapon_slot}),
             true <- weapon.channel_time_remaining > 0
        do
          true
        else
          _ ->
            false
        end
      end

      defp update_channel_time(weapon, arena) do
        update_in(weapon.channel_time_remaining, &(max(0, &1 - arena.delta_time * 1000)))
      end

      defp update_weapon(weapon, arena) do
        Weapon.update_weapon(weapon, arena)
      end

      defoverridable [fire: 3, run: 2, on_cooldown: 3, on_hit: 3, on_channel: 3]
    end
  end

  @spec fire(t, Position.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def fire(weapon, target_position, arena) do
    full_module_name = find_module_name(weapon.weapon_name)

    case {is_on_cooldown?(weapon), is_out_of_energy?(weapon, arena)} do
      {true, _} ->
        apply(full_module_name, :on_cooldown, [weapon, target_position, arena])
      {_, true} ->
        {:ok, arena}
      _ ->
        weapon = start_cooling_down(weapon)
        {:ok, arena} = expend_energy(weapon, arena)
        {:ok, {weapon, arena}} = start_channeling(weapon, arena)
        {:ok, arena} = update_weapon(weapon, arena)
        apply(full_module_name, :fire, [weapon, target_position, arena])
    end
  end

  @spec run(t, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def run(weapon, arena) do
    find_module_name(weapon.weapon_name)
    |> apply(:run, [weapon, arena])
  end

  @spec cooldown_progress(t) :: number
  def cooldown_progress(weapon) do
    1 - (weapon.cooldown_remaining / weapon.cooldown)
  end

  @spec on_hit(String.t, Actor.t, number, Arena.t) :: {:ok, number} | {:error, term}
  def on_hit(weapon_type, actor, damage, arena) do
    with {:ok, arsenal} <- Components.fetch(arena.components, :arsenal, actor),
         {_, weapon} <- Enum.find(arsenal.component_data.weapons, &(elem(&1, 1).weapon_name == weapon_type))
    do
      module_name = find_module_name(weapon_type)
      apply(module_name, :on_hit, [weapon, damage, arena])
    else
      _ ->
        {:ok, damage}
    end
  end

  @spec update_weapon(t, Arena.t) :: {:ok, Arena.t} | {:error, term}
  def update_weapon(weapon, arena) do
    Arena.update_component(arena, :arsenal, weapon.actor, fn arsenal ->
      Arsenal.put_weapon(arsenal, weapon)
    end)
  end

  defp is_on_cooldown?(weapon) do
    weapon.cooldown_remaining > 0
  end

  defp is_out_of_energy?(weapon, arena) do
    with {:ok, stats} <- Stats.get_readonly(arena, weapon.actor)
    do
      weapon.energy_cost > stats.component_data.energy
    else
      _ ->
        false
    end
  end

  defp expend_energy(weapon, arena) do
    Arena.update_component(arena, :stats, weapon.actor, fn stats ->
      Stats.expend_energy(stats, weapon.energy_cost, arena)
    end)
  end

  defp start_cooling_down(weapon) do
    put_in(weapon.cooldown_remaining, weapon.cooldown)
  end

  defp find_module_name(weapon_name) do
    weapon_name
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Weapons, &1)).()
  end

  defp start_channeling(%{channel_time: 0} = weapon, arena) do
    {:ok, {weapon, arena}}
  end

  defp start_channeling(weapon, arena) do
    with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, weapon.actor)
    do
      path = if weapon.channel_effect_path == "default" do
               @default_channel_effect
             else
               weapon.channel_effect_path
             end

      channel = Channel.new(weapon.weapon_slot, path)
      {:ok, arena} = BuffDebuffStack.apply(buff_debuff_stack, channel, arena)

      weapon = put_in(weapon.channeling, true)
      weapon = put_in(weapon.channel_time_remaining, weapon.channel_time)

      {:ok, {weapon, arena}}
    else
      _ ->
        {:ok, {weapon, arena}}
    end
  end

end
