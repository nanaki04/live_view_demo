defmodule SpaceBirds.Logic.Edge do
  alias SpaceBirds.Logic.Vector2

  @type t :: %{
    a: Vector2.t,
    b: Vector2.t
  }

  defstruct a: Vector2.new(0, 0),
    b: Vector2.new(0, 0)

  def new(a, b) do
    %__MODULE__{a: a, b: b}
  end

  def intersects?(edge1, edge2) do
    case {m(edge1), b(edge1), m(edge2), b(edge2)} do
      {:infinity, :invalid, :infinity, :invalid} ->
        edge1.a.x == edge2.a.x && (point_on_vertical_line?(edge1, edge2.a) || point_on_vertical_line?(edge1, edge2.b))
      {:infinity, :invalid, m, b} ->
        y = m * edge1.a.x - b
        point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y)
      {m, b, :infinity, :invalid} ->
        y = m * edge2.a.x - b
        point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y)
      {m1, b1, m2, b2} when m1 == m2 and b1 == b2 ->
        point_on_vertical_line?(edge1, edge2.a) || point_on_vertical_line?(edge1, edge2.b)
      {m1, _b1, m2, _b2} when m1 == m2 ->
        false
      {m1, b1, m2, b2} ->
        x = (b2 - b1) / (m1 - m2)
        y = m1 * x - b1
        point_on_vertical_line?(edge1, %{x: x, y: y}) && point_on_vertical_line?(edge2, %{x: x, y: y})
    end
  end

  defp m(%{a: a, b: b}) do
    case Vector2.sub(b, a) do
      %{x: 0} -> :infinity
      %{x: 0.0} -> :infinity
      %{x: x, y: y} -> y / x
    end
  end

  defp b(%{a: a} = edge) do
    case m(edge) do
      :infinity -> :invalid
      m -> a.y - m * a.x
    end
  end

  defp point_on_vertical_line?(vertical_line, point) do
    point.y >= min(vertical_line.a.y, vertical_line.b.y) && point.y <= max(vertical_line.a.y, vertical_line.b.y)
  end

end
