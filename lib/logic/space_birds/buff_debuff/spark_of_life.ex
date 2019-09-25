defmodule SpaceBirds.BuffDebuff.SparkOfLife do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Components.Team
  alias SpaceBirds.Logic.ProgressOverTime
  alias SpaceBirds.MasterData
  use SpaceBirds.BuffDebuff.BuffDebuff

  @type t :: %{
    bolt_strength: number,
    bolt_count: number,
    bolt_count_left: number,
    bolt_path: MasterData.projectile_type
  }

  defstruct bolt_strength: 0,
    bolt_count: 0,
    bolts_fired: 0,
    bolt_path: "default"

  @default_bolt_path "spark_of_life_heal"

  @impl(BuffDebuff)
  def run(spark_of_life, buff_debuff_stack, arena) do
    {:ok, arena} = evaluate_expiration(spark_of_life, buff_debuff_stack, arena)

    progress = 1 - (spark_of_life.time_remaining / spark_of_life.time)
    next_spark = floor(ProgressOverTime.linear(%{from: 0, to: spark_of_life.buff_data.bolt_count}, progress))

    with current_spark when next_spark > current_spark <- spark_of_life.buff_data.bolts_fired
    do
      {:ok, arena} = spawn_bolt(spark_of_life, buff_debuff_stack, arena)
      spark_of_life = put_in(spark_of_life.buff_data.bolts_fired, next_spark)

      update_in_stack(spark_of_life, buff_debuff_stack, arena)
    else
      _ ->
        {:ok, arena}
    end
  end

  def spawn_bolt(spark_of_life, buff_debuff_stack, arena) do
    projectile_id = arena.last_actor_id + 1
    actor = buff_debuff_stack.actor

    {:ok, transform} = Components.fetch(arena.components, :transform, actor)
    position = transform.component_data.position

    path = case spark_of_life.buff_data.bolt_path do
      "default" -> @default_bolt_path
      path -> path
    end

    {:ok, projectile} = MasterData.get_projectile(path, projectile_id, actor)
    {:ok, projectile} = Team.copy_team(projectile, arena, actor)
    projectile = put_in(projectile.transform.component_data.position, position)

    Arena.add_actor(arena, projectile)
  end

end
