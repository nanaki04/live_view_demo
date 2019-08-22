defmodule SpaceBirds.Animations.TextureFrame do
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Animations.Tween
  use SpaceBirds.Animations.Frame

  @type t :: %{
    value: number,
    path: String.t
  }

  @impl(Frame)
  def run(frame, animation_component, arena) do
    change_texture(frame.frame_data.path, frame.frame_data.value, animation_component, arena)
  end

  @impl(Frame)
  def run_tween(last, next, animation, animation_component, arena) do
    value = Tween.calculate_value(last, next, last.frame_data.value, next.frame_data.value, animation.time)
            |> floor

    change_texture(last.frame_data.path, value, animation_component, arena)
  end

  defp change_texture(path, idx, animation_component, arena) do
    idx = idx
          |> to_string
          |> String.pad_leading(4, "0")

    Arena.update_component(arena, :texture, animation_component.actor, fn
      texture -> {:ok, put_in(texture.component_data.path, "#{path}_#{idx}.png")}
    end)
  end

end
