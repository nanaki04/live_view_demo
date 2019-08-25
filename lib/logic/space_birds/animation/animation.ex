defmodule SpaceBirds.Animations.Animation do
  alias SpaceBirds.Animations.Frame
  alias SpaceBirds.State.Arena
  alias SpaceBirds.Components.AnimationPlayer
  use SpaceBirds.Utility.MapAccess

  @type frame_type :: String.t

  @type t :: %{
    id: number,
    time: number,
    duration: number,
    is_loop?: boolean,
    key_frames: %{
      optional(frame_type) => %{past: [Frame.t], next: [Frame.t]}
    }
  }

  defstruct id: 0,
    key_frames: %{},
    time: 0,
    duration: 1,
    is_loop?: false

  @spec run(t, AnimationPlayer.t, Arena.t) :: {:ok, Arena.t} | {:error, String.t}
  def run(animation, animation_component, arena) do
    animation = update_in(animation.time, & &1 + arena.delta_time * 1000)
    {:ok, animation_component} = AnimationPlayer.update_animation(animation_component, animation)
    {:ok, arena} = Arena.update_component(arena, animation_component, fn _ -> {:ok, animation_component} end)

    {:ok, arena} = filter_procced_key_frames(animation.key_frames, animation.time)
                   |> run_key_frames(animation, animation_component, arena)

    run_tweens(animation, animation_component, arena)
  end

  defp run_key_frames([], _animation, _animation_component, arena) do
    {:ok, arena}
  end

  defp run_key_frames(procced_key_frames, animation, animation_component, arena) do
    key_frames = move_handled_key_frames(procced_key_frames, animation.key_frames)
    animation = put_in(animation.key_frames, key_frames)
    animation = reset_loop_animation(animation)
    {:ok, animation_component} = AnimationPlayer.update_animation(animation_component, animation)
    {:ok, arena} = Arena.update_component(arena, animation_component, fn _ -> {:ok, animation_component} end)
    {:ok, arena} = run_procced_key_frames(procced_key_frames, animation_component, arena)

    filter_procced_key_frames(animation.key_frames, animation.time)
    |> run_key_frames(animation, animation_component, arena)
  end

  defp run_tweens(animation, animation_component, arena) do
    filter_tweens(animation.key_frames)
    |> Enum.reduce({:ok, arena}, fn
      {frame_type, %{past: past, next: next}}, {:ok, arena} ->
        last = hd(past)
        next = hd(next)
        get_module_name(to_string(frame_type))
        |> apply(:run_tween, [last, next, animation, animation_component, arena])
      _, acc ->
        acc
    end)
  end

  defp reset_loop_animation(%{is_loop?: false} = animation), do: animation

  defp reset_loop_animation(%{time: time, duration: duration} = animation) when time < duration, do: animation

  defp reset_loop_animation(animation) do
    update_in(animation.key_frames, fn key_frames ->
      Enum.reduce(key_frames, key_frames, fn
        {frame_type, %{past: past, next: []}}, key_frames ->
          Map.put(key_frames, frame_type, %{past: [], next: Enum.reverse(past)})
        _, key_frames ->
          key_frames
      end)
      |> Enum.into(%{})
    end)
    |> Map.put(:time, animation.time - animation.duration)
  end

  defp move_handled_key_frames(procced_key_frames, key_frames) do
    Enum.reduce(procced_key_frames, key_frames, fn
      {frame_type, %{next: [procced | next]}}, key_frames ->
        key_frames = update_in(key_frames[frame_type].past, & [procced | &1])
        put_in(key_frames[frame_type].next, next)
      _, key_frames ->
        key_frames
    end)
    |> Enum.into(%{})
  end

  defp run_procced_key_frames(procced_key_frames, animation_component, arena) do
    Enum.reduce(procced_key_frames, {:ok, arena}, fn
      {frame_type, %{next: [procced_key_frame | _]}}, {:ok, arena} ->
        get_module_name(to_string(frame_type))
        |> apply(:run, [procced_key_frame, animation_component, arena])
      _, error ->
        error
    end)
  end

  defp filter_procced_key_frames(key_frames, animation_time) do
    key_frames
    |> Enum.filter(& has_procced_key_frame?(&1, animation_time))
  end

  defp has_procced_key_frame?({_, %{next: []}}, _animation_time) do
    false
  end

  defp has_procced_key_frame?({_, %{next: [%{time: frame_time} | _]}}, animation_time) do
    frame_time <= animation_time
  end

  defp filter_tweens(key_frames) do
    key_frames
    |> Enum.filter(fn
      {_, %{past: []}} ->
        false
      {_, %{next: []}} ->
        false
      {_, %{next: [%{tween_type: tween_type} | _]}} when tween_type != "none" ->
        true
      _ ->
        false
    end)
  end

  defp get_module_name(frame_type) do
    frame_type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join
    |> (& Module.concat(SpaceBirds.Animations, &1)).()
  end

end
