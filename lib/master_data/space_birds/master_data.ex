defmodule SpaceBirds.MasterData do
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Players

  @base_path "lib/master_data/space_birds/"

  @type t :: %{term => term}

  @type fighter_type :: String.t

  @type arena_type :: String.t

  @type projectile_type :: String.t

  @type on_hit_effect_type :: String.t

  @type buff_debuff_type :: String.t

  @spec get_fighter_types() :: [fighter_type]
  def get_fighter_types() do
    with {:ok, json} <- File.read("#{@base_path}fighter_types.json"),
         {:ok, fighter_types} <- Jason.decode(json)
    do
      {:ok, fighter_types}
    else
      error ->
        error
    end
  end

  @spec get_player_fighter(fighter_type, Actor.t, Players.player_id) :: {:ok, t} | {:error, String.t}
  def get_player_fighter(fighter_type, actor_id, player_id) do
    with {:ok, fighter} <- get_fighter(fighter_type, actor_id) do
      fighter
      |> put_in([:movement_controller, :component_data, :owner], player_id)
      |> put_in([:arsenal, :component_data, :owner], {:some, player_id})
      |> put_in([:ui, :component_data, :owner], player_id)
      |> ResultEx.return
    else
      error ->
        error
    end
  end

  @spec get_fighter(fighter_type, Actor.t) :: {:ok, t} | {:error, String.t}
  def get_fighter(fighter_type, actor_id) do
    with {:ok, json} <- File.read("#{@base_path}fighter_#{fighter_type}.json"),
         {:ok, fighter} <- Jason.decode(json, keys: :atoms)
    do
      fighter
      |> put_in([:collider, :component_data, :owner], actor_id)
      |> update_in([:arsenal, :component_data, :weapons], fn weapons ->
        Enum.reduce(weapons, %{}, fn weapon, weapons ->
          Map.put(weapons, weapon.weapon_slot, %{weapon | actor: actor_id})
        end)
      end)
      |> ResultEx.return
    else
      error ->
        error
    end
  end

  @spec get_camera(Players.player_id, Actor.t) :: {:ok, t} | {:error, String.t}
  def get_camera(player_id, fighter_id) do
    with {:ok, json} <- File.read("#{@base_path}camera.json"),
         {:ok, camera} <- Jason.decode(json, keys: :atoms)
    do
      camera
      |> put_in([:camera, :component_data, :owner], player_id)
      |> put_in([:follow, :component_data, :target], fighter_id)
      |> ResultEx.return
    else
      error ->
        error
    end
  end

  @spec get_map(arena_type) :: {:ok, t} | {:error, String.t}
  def get_map(arena_type) do
    with {:ok, json} <- File.read("#{@base_path}#{arena_type}.json"),
         {:ok, arena} <- Jason.decode(json, keys: :atoms)
    do
      {:ok, arena}
    else
      error ->
        error
    end
  end

  @spec get_background(arena_type) :: {:ok, t} | {:error, String.t}
  def get_background(arena_type) do
    with {:ok, json} <- File.read("#{@base_path}background_#{arena_type}.json"),
         {:ok, background} <- Jason.decode(json, keys: :atoms)
    do
      {:ok, background}
    else
      error ->
        error
    end
  end

  @spec get_projectile(projectile_type, Actor.t, Actor.t) :: {:ok, t} | {:error, String.t}
  def get_projectile(projectile_type, actor_id, owner_actor_id) do
    with {:ok, json} <- File.read("#{@base_path}#{projectile_type}.json"),
         {:ok, projectile} <- Jason.decode(json, keys: :atoms)
    do
      projectile
      |> put_in([:movement_controller, :component_data, :owner], {:actor, actor_id})
      |> put_in([:collider, :component_data, :owner], owner_actor_id)
      |> ResultEx.return
    else
      error ->
        error
    end
  end

  @spec get_on_hit_effect(on_hit_effect_type) :: {:ok, t} | {:error, String.t}
  def get_on_hit_effect(on_hit_effect_type) do
    with {:ok, json} <- File.read("#{@base_path}on_hit_effect_#{on_hit_effect_type}.json"),
         {:ok, on_hit_effect} <- Jason.decode(json, keys: :atoms)
    do
      {:ok, on_hit_effect}
    else
      error ->
        error
    end
  end

  @spec get_buff_debuff(buff_debuff_type) :: {:ok, BuffDebuff.t} | {:error, String.t}
  def get_buff_debuff(buff_debuff_type) do
    with {:ok, json} <- File.read("#{@base_path}buff_debuff_#{buff_debuff_type}.json"),
         {:ok, buff_debuff} <- Jason.decode(json, keys: :atoms)
    do
      {:ok, buff_debuff}
    else
      error ->
        error
    end
  end

end
