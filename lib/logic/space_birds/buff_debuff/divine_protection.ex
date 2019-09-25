defmodule SpaceBirds.BuffDebuff.DivineProtection do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Components.BuffDebuffStack
  alias SpaceBirds.MasterData
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    absorb_per_hit: number,
    damage_absorbed: number,
    on_remove_effect: MasterData.projectile_type
  }

  @impl(BuffDebuff)
  def on_remove(divine_protection, buff_debuff_stack, arena) do
    projectile_id = arena.last_actor_id + 1
    actor = divine_protection.owner

    {:ok, transform} = Components.fetch(arena.components, :transform, actor)
    position = transform.component_data.position

    {:ok, projectile} = MasterData.get_projectile(divine_protection.buff_data.on_remove_effect, projectile_id, actor)
    {:ok, projectile} = Team.copy_team(projectile, arena, buff_debuff_stack.actor)
    projectile = update_in(projectile.damage.component_data.damage, &(&1 + divine_protection.buff_data.damage_absorbed))
    projectile = put_in(projectile.transform.component_data.position, position)

    {:ok, arena} = Arena.add_actor(arena, projectile)

    remove_from_stack(divine_protection, buff_debuff_stack, arena)
    |> ResultEx.bind(&remove_visual_effect(divine_protection, buff_debuff_stack, &1))
  end

  @spec absorb(damage :: number, holder :: Actor.t, Arena.t) :: {:ok, {number, Arena.t}} | {:error, term}
  def absorb(damage, holder, arena) do
    with {:ok, buff_debuff_stack} <- Components.fetch(arena.components, :buff_debuff_stack, holder),
         [_ | _] = divine_protections <- BuffDebuffStack.filter_by_type(buff_debuff_stack, "divine_protection")
    do
      Enum.reduce(divine_protections, {:ok, damage, arena}, fn buff_debuff, {:ok, damage, arena} ->

        absorbed = min(damage, buff_debuff.buff_data.absorb_per_hit)
        buff_debuff = update_in(buff_debuff.buff_data.damage_absorbed, &(&1 + absorbed))
        damage = damage - absorbed

        {:ok, arena} = Arena.update_component(arena, :buff_debuff_stack, holder, fn buff_debuff_stack ->
          update_in(buff_debuff_stack.component_data.buff_debuffs, fn buff_debuffs ->
            Map.put(buff_debuffs, buff_debuff.id, buff_debuff)
          end)
          |> ResultEx.return
        end)

        {:ok, {damage, arena}}

      end)
    else
      _ ->
        {:ok, {damage, arena}}
    end
  end

end
