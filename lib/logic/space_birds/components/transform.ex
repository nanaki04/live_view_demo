defmodule SpaceBirds.Components.Transform do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Rotation
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Logic.Edge
  alias SpaceBirds.Logic.ProgressOverTime
  use Component

  @type t :: %{
    position: Position.t,
    rotation: Rotation.t,
    size: Size.t,
    layer: String.t
  }

  defstruct position: %Position{},
    rotation: 0,
    size: %Size{}

  @spec get_vertices(Component.t) :: [Position.t]
  def get_vertices(transform) do
    pos = transform.component_data.position
    rot = transform.component_data.rotation
    size = transform.component_data.size

    p1 = %{x: -size.width / 2, y: -size.height / 2}
    p2 = %{x: size.width / 2, y: -size.height / 2}
    p3 = %{x: size.width / 2, y: size.height / 2}
    p4 = %{x: -size.width / 2, y: size.height / 2}

    distance = Vector2.distance(p1)

    rot1 = Vector2.to_rotation(p1)
    rot2 = Vector2.to_rotation(p2)
    rot3 = Vector2.to_rotation(p3)
    rot4 = Vector2.to_rotation(p4)

    p1 = Vector2.mul(Vector2.from_rotation(Rotation.add(rot, rot1)), distance)
    p2 = Vector2.mul(Vector2.from_rotation(Rotation.add(rot, rot2)), distance)
    p3 = Vector2.mul(Vector2.from_rotation(Rotation.add(rot, rot3)), distance)
    p4 = Vector2.mul(Vector2.from_rotation(Rotation.add(rot, rot4)), distance)

    p1 = Vector2.add(p1, pos)
    p2 = Vector2.add(p2, pos)
    p3 = Vector2.add(p3, pos)
    p4 = Vector2.add(p4, pos)

    [
      p1,
      p2,
      p3,
      p4
    ]
  end

  @spec get_edges(Component.t) :: [Edge.t]
  def get_edges(transform) do
    [p1, p2, p3, p4] = get_vertices(transform)

    [
      Edge.new(p1, p2),
      Edge.new(p2, p3),
      Edge.new(p3, p4),
      Edge.new(p4, p1)
    ]
  end

  @spec offset(Component.t, Position.t) :: Position.t
  def offset(transform, offset) do
    pos = transform.component_data.position
    b = Vector2.add(pos, offset)
    Edge.rotate(%{a: pos, b: b}, transform.component_data.rotation).b
  end

  @spec distance_to(transform1 :: Component.t, transform2 :: Component.t) :: number
  def distance_to(transform1, transform2) do
    Edge.distance(%{a: transform1.component_data.position, b: transform2.component_data.position})
  end

  @spec find_closest_target(transform :: Component.t, target_transforms :: [Component.t]) :: {:some, Component.t} | :none
  def find_closest_target(_, []), do: :none

  def find_closest_target(transform, target_transforms) do
    Enum.reduce(target_transforms, :none, fn
      target_transform, :none ->
        {:some, target_transform}
      target_transform, {:some, closest_target} ->
        if distance_to(transform, target_transform) <= distance_to(transform, closest_target) do
          {:some, target_transform}
        else
          {:some, closest_target}
        end
    end)
  end

  @spec look_at(transform1 :: Component.t, transform2 :: Component.t) :: {:ok, Component.t} | {:error, String.t}
  def look_at(transform1, transform2) do
    rotation = Edge.to_rotation(%{a: transform1.component_data.position, b: transform2.component_data.position})
    {:ok, put_in(transform1.component_data.rotation, rotation)}
  end

  @spec look_at_over_time(transform1 :: Component.t, transform2 :: Component.t, speed :: number, ProgressOverTime.curve, Arena.t) :: {:ok, Component.t} | {:error, String.t}
  def look_at_over_time(transform1, transform2, speed, progress_curve, arena) do
    rotation = Edge.to_rotation(%{a: transform1.component_data.position, b: transform2.component_data.position})
    rotation = apply(ProgressOverTime, progress_curve, [
      %{
        from: transform1.component_data.rotation,
        to: rotation
      },
      calculate_look_at_progress(transform1, rotation, speed, arena)
    ])

    {:ok, put_in(transform1.component_data.rotation, rotation)}
  end

  defp calculate_look_at_progress(transform1, destination, speed, arena) do
    Rotation.distance(transform1.component_data.rotation, destination)
    |> Rotation.add(arena.delta_time * -speed)
    |> Kernel./(180)
    |> max(0)
    |> min(1)
    |> (&(1 - &1)).()
  end

end
