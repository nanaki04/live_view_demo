defmodule SpaceBirds.Animations.Frame do
  alias SpaceBirds.Components.AnimationPlayer
  alias SpaceBirds.Animations.Animation
  alias SpaceBirds.State.Arena

  @type frame_type :: String.t

  @type tween_type :: String.t

  @type milliseconds :: number

  @type frame_data :: %{}

  @type t :: %{
    type: frame_type,
    time: milliseconds,
    tween_type: tween_type,
    frame_data: frame_data
  }

  @callback run(t, AnimationPlayer.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  @callback run_tween(last_frame :: t, next_frame :: t, Animation.t, AnimationPlayer.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}

  defstruct type: "",
    time: 0,
    tween_type: "none",
    frame_data: %{}

  defmacro __using__(_opts) do
    quote do
      alias SpaceBirds.Animations.Frame
      @behaviour Frame

      @impl(Frame)
      def run(_frame, _animation_component, arena) do
        {:ok, arena}
      end

      @impl(Frame)
      def run_tween(_last_frame, _next_frame, _animation, _animation_component, arena) do
        {:ok, arena}
      end

      defoverridable [run: 3, run_tween: 5]
    end
  end

end
