defmodule SpaceBirds.Components.Transform do
  alias SpaceBirds.Components.Component
  alias SpaceBirds.Logic.Position
  alias SpaceBirds.Logic.Rotation
  alias SpaceBirds.Logic.Size
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Logic.Edge
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

end
