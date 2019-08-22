defmodule SpaceBirds.Components.AnimationPlayer do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Animations.Animation
  alias SpaceBirds.MasterData
  use Component

  @type animation_id :: number

  @type t :: %{
    animations: %{
      required(:last_id) => number,
      optional(animation_id) => Animation.t
    },
  }

  defstruct animations: %{last_id: 0}

  @impl(Component)
  def run(component, arena) do
    Enum.reduce(component.component_data.animations, {:ok, arena}, fn
      {:last_id, _}, {:ok, arena} ->
        {:ok, arena}
      {_, animation}, {:ok, arena} ->
        Animation.run(animation, component, arena)
      _, result ->
        result
    end)
  end

  @spec play_animation(Component.t, MasterData.animation_type, number) :: {:ok, t} | {:error, String.t}
  def play_animation(component, animation_type, animation_speed \\ 1) do
    {:ok, component} = clear_animations(component)
    {:ok, animations} = MasterData.get_animation(animation_type, animation_speed)

    Enum.reduce(animations, {:ok, component}, fn
      animation, {:ok, component} ->
        add_animation(component, animation)
      _, error ->
        error
    end)
  end

  @spec add_animation(t, Animation.t) :: {:ok, t} | {:error, String.t}
  def add_animation(component, animation) do
    animation_id = component.component_data.animations.last_id + 1
    put_in(component.component_data.animations.last_id, animation_id)
    update_in(component.component_data.animations, & Map.put(&1, animation_id, Map.put(animation, :id, animation_id)))
    |> ResultEx.return
  end

  @spec update_animation(t, Animation.t) :: {:ok, t} | {:error, String.t}
  def update_animation(component, animation) do
    put_in(component.component_data.animations[animation.id], animation)
    |> ResultEx.return
  end

  @spec clear_animations(t) :: {:ok, t} | {:error, String.t}
  def clear_animations(component) do
    put_in(component.component_data.animations, %{last_id: 0})
    |> ResultEx.return
  end
end
