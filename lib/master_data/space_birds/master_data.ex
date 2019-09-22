defmodule SpaceBirds.MasterData do
  alias SpaceBirds.Logic.Actor
  alias SpaceBirds.State.Players
  alias SpaceBirds.Animations.Animation

  # TODO cache all master data in GenServers and add a seed command

  @base_path "lib/master_data/space_birds/"

  @type t :: %{term => term}

  @type fighter_type :: String.t

  @type arena_type :: String.t

  @type projectile_type :: String.t

  @type on_hit_effect_type :: String.t

  @type buff_debuff_type :: String.t

  @type animation_type :: String.t

  @type visual_effect_type :: String.t

  @type prototype :: String.t

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

  @spec get_player_fighter(fighter_type, Actor.t, Players.t) :: {:ok, t} | {:error, String.t}
  def get_player_fighter(fighter_type, actor_id, player) do
    with {:ok, fighter} <- get_fighter(fighter_type, actor_id) do
      fighter
      |> put_in([:movement_controller, :component_data, :owner], player.id)
      |> put_in([:arsenal, :component_data, :owner], {:some, player.id})
      |> put_in([:ui, :component_data, :owner], player.id)
      |> put_in([:score, :component_data, :name], player.name)
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
      projectile = case Map.fetch(projectile, :movement_controller) do
        {:ok, _} ->
          put_in(projectile.movement_controller.component_data.owner, {:actor, actor_id})
        _ ->
          projectile
      end

      projectile = case Map.fetch(projectile, :collider) do
        {:ok, _} ->
          put_in(projectile.collider.component_data.owner, owner_actor_id)
        _ ->
          projectile
      end

      {:ok, projectile}
    else
      error ->
        error
    end
  end

  @spec get_on_hit_effect(on_hit_effect_type) :: {:ok, t} | {:error, String.t}
  def get_on_hit_effect(on_hit_effect_type) do
    with {:ok, json} <- File.read("#{@base_path}on_hit_effects/#{on_hit_effect_type}.json"),
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

  @spec get_animation(animation_type, animation_speed :: number) :: {:ok, [Animation.t]} | {:error, String.t}
  def get_animation(animation_type, animation_speed \\ 1) do
    with {:ok, json} <- File.read("#{@base_path}animations/#{animation_type}.json"),
         {:ok, animations} <- Jason.decode(json, keys: :atoms)
    do
      Enum.map(animations, fn animation ->
        Map.update(animation, :duration, 1000, & &1 * animation_speed)
        |> Map.update(:key_frames, %{}, fn key_frames ->
          Enum.map(key_frames, fn {type, key_frame_list} ->
            {type, update_in(key_frame_list.next, fn next ->
              Enum.map(next, fn next -> update_in(next.time, & &1 * animation_speed) end)
            end)}
          end)
        end)
      end)
      |> ResultEx.return
    else
      error ->
        error
    end
  end

  @spec get_visual_effect(visual_effect_type) :: {:ok, t} | {:error, String.t}
  def get_visual_effect(visual_effect_type) do
    with {:ok, json} <- File.read("#{@base_path}visual_effects/#{visual_effect_type}.json"),
         {:ok, effect} <- Jason.decode(json, keys: :atoms)
    do
      {:ok, effect}
    else
      error ->
        error
    end
  end

  @spec get_prototype(prototype, Actor.t) :: {:ok, t} | {:error, String.t}
  def get_prototype(prototype, actor_id) do
    with {:ok, json} <- File.read("#{@base_path}prototypes/#{prototype}.json"),
         {:ok, prototype} <- Jason.decode(json, keys: :atoms)
    do
      prototype = case Map.fetch(prototype, :arsenal) do
        {:ok, _} ->
          prototype = put_in(prototype.arsenal.component_data.owner, :none)
          update_in(prototype.arsenal.component_data.weapons, fn weapons ->
            Enum.reduce(weapons, %{}, fn weapon, weapons ->
              Map.put(weapons, weapon.weapon_slot, %{weapon | actor: actor_id})
            end)
          end)
        _ ->
          prototype
      end

      prototype = case Map.fetch(prototype, :collider) do
        {:ok, _} ->
          put_in(prototype.collider.component_data.owner, actor_id)
        _ ->
          prototype
      end

      {:ok, prototype}
    else
      error ->
        error
    end
  end

  @spec get_prototypes(arena_type, Actor.t) :: [t]
  def get_prototypes(arena_type, next_actor_id) do
    with {:ok, json} <- File.read("#{@base_path}prototypes_#{arena_type}.json"),
         {:ok, prototypes} <- Jason.decode(json, keys: :atoms)
    do
      {_, prototypes} = Enum.reduce(prototypes, {next_actor_id, []}, fn %{x: x, y: y, prototype: prototype}, {next_id, prototypes} -> 
        {:ok, prototype} = get_prototype(prototype, next_id)
        prototype = put_in(prototype.transform.component_data.position, %{x: x, y: y})
        {next_id + 1, [prototype | prototypes]}
      end)

      {:ok, Enum.reverse(prototypes)}
    else
      error ->
        error
    end
  end

  @spec get_spawner(prototype) :: {:ok, t} | {:error, atom}
  def get_spawner(prototype) do
    with {:ok, json} <- File.read("#{@base_path}spawner.json"),
         {:ok, spawner} <- Jason.decode(json, keys: :atoms)
    do
      spawner = put_in(spawner.spawner.component_data.prototype, prototype)
      {:ok, spawner}
    else
      error ->
        error
    end
  end

end
