defmodule SpaceBirds.Animations.OpacityFrame do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.Components
  alias SpaceBirds.Animations.Tween
  use SpaceBirds.Animations.Frame

  @type t :: %{
    value: number
  }

  @impl(Frame)
  def run(frame, animation_component, arena) do
    {:ok, arena} = adjust_paint(frame.frame_data.value, animation_component, arena)
    adjust_texture(frame.frame_data.value, animation_component, arena)
  end

  @impl(Frame)
  def run_tween(last, next, animation, animation_component, arena) do
    value = Tween.calculate_value(last, next, last.frame_data.value, next.frame_data.value, animation.time)
    {:ok, arena} = adjust_paint(value, animation_component, arena)
    adjust_texture(value, animation_component, arena)
  end

  defp adjust_paint(new_value, animation_component, arena) do
    with {:ok, _} <- Components.fetch(arena.components, :paint, animation_component.actor)
    do
      Arena.update_component(arena, :paint, animation_component.actor, fn
        paint -> {:ok, put_in(paint.component_data.color.a, new_value)}
      end)
    else
      _ -> {:ok, arena}
    end
  end

  defp adjust_texture(new_value, animation_component, arena) do
    with {:ok, _} <- Components.fetch(arena.components, :texture, animation_component.actor)
    do
      Arena.update_component(arena, :texture, animation_component.actor, fn
        texture -> {:ok, put_in(texture.component_data.opacity, new_value)}
      end)
    else
      _ -> {:ok, arena}
    end
  end

end
