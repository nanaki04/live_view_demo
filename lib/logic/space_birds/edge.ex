defmodule SpaceBirds.Logic.Edge do
  alias SpaceBirds.Logic.Vector2
  alias SpaceBirds.Logic.Math
  import Kernel, except: [round: 1]

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
        y = m * edge1.a.x + b
        point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y)
      {m, b, :infinity, :invalid} ->
        y = m * edge2.a.x + b
        point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y)
      {m1, b1, m2, b2} when m1 == m2 and b1 == b2 ->
        point_on_vertical_line?(edge1, edge2.a) || point_on_vertical_line?(edge1, edge2.b)
      {m1, _b1, m2, _b2} when m1 == m2 ->
        false
      {m1, b1, m2, b2} ->
        x = (b2 - b1) / (m1 - m2)
        y = m1 * x + b1
        point_on_vertical_line?(edge1, %{x: x, y: y}) && point_on_vertical_line?(edge2, %{x: x, y: y})
    end
  end

  def intersects_at(edge1, edge2) do
    case {m(edge1), b(edge1), m(edge2), b(edge2)} do
      {:infinity, :invalid, :infinity, :invalid} ->
        if edge1.a.x == edge2.a.x && (point_on_vertical_line?(edge1, edge2.a) || point_on_vertical_line?(edge1, edge2.b)) do
          edge1.a
          |> Vector2.add(edge1.b)
          |> Vector2.add(edge2.a)
          |> Vector2.add(edge2.b)
          |> Vector2.div(4)
          |> OptionEx.return
        else
          :none
        end
      {:infinity, :invalid, m, b} ->
        y = m * edge1.a.x + b
        if point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y) do
          {:some, %{x: edge1.a.x, y: y}}
        else
          :none
        end
      {m, b, :infinity, :invalid} ->
        y = m * edge2.a.x + b
        if point_on_vertical_line?(edge1, y) && point_on_vertical_line?(edge2, y) do
          {:some, %{x: edge2.a.x, y: y}}
        else
          :none
        end
      {m1, b1, m2, b2} when m1 == m2 and b1 == b2 ->
        if point_on_vertical_line?(edge1, edge2.a) || point_on_vertical_line?(edge1, edge2.b) do
          edge1.a
          |> Vector2.add(edge1.b)
          |> Vector2.add(edge2.a)
          |> Vector2.add(edge2.b)
          |> Vector2.div(4)
          |> OptionEx.return
        else
          :none
        end
      {m1, _b1, m2, _b2} when m1 == m2 ->
        :none
      {m1, b1, m2, b2} ->
        x = (b2 - b1) / (m1 - m2)
        y = m1 * x + b1
        point = %{x: Kernel.round(x), y: Kernel.round(y)}
        edge1 = round(edge1)
        edge2 = round(edge2)
        if point_on_vertical_line?(edge1, point)
           && point_on_vertical_line?(edge2, point)
           && point_on_horizontal_line?(edge1, point)
           && point_on_horizontal_line?(edge2, point)
        do
          {:some, point}
        else
          :none
        end
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

  def distance(%{a: %{x: x1, y: y1}, b: %{x: x2, y: y2}}) do
    Vector2.distance(%{x: x2 - x1, y: y2 - y1})
  end

  def to_rotation(%{a: %{x: x1, y: y1}, b: %{x: x2, y: y2}}) do
    Vector2.to_rotation(%{x: x2 - x1, y: y2 - y1})
  end

  def rotate_by_distance(edge, 0.0) do
    edge
  end

  def rotate_by_distance(edge, 0) do
    edge
  end

  def rotate_by_distance(edge, distance) do
    case distance(edge) do
      0 ->
        edge
      0.0 ->
        edge
      edge_distance ->
        rotation = Math.asin((distance / 2) / edge_distance) * 2
        rotate(edge, rotation)
    end
  end

  def rotate(%{a: a} = edge, rotation) do
    current_rotation = to_rotation(edge)
    total_rotation = rem(Kernel.round(current_rotation + rotation) + 360, 360)
    unit_vector = Vector2.from_rotation(total_rotation)
    distance = distance(edge)
    b = Vector2.mul(unit_vector, distance)
        |> Vector2.add(a)

    %{a: a, b: b}
  end

  def is_starboard?(edge, point) do
    rotation = to_rotation(edge)
    vertical = rotate(edge, -rotation)
    %{b: rotated_point} = rotate(%{a: edge.a, b: point}, -rotation)
    point_on_vertical_line?(vertical, rotated_point) && rotated_point.x >= edge.a.x
  end

  defp point_on_vertical_line?(vertical_line, point) when is_number(point) do
    point_on_vertical_line?(vertical_line, %{x: 0, y: point})
  end

  defp point_on_vertical_line?(vertical_line, point) do
    point.y >= min(vertical_line.a.y, vertical_line.b.y) && point.y <= max(vertical_line.a.y, vertical_line.b.y)
  end

  defp point_on_horizontal_line?(horizontal_line, point) when is_number(point) do
    point_on_horizontal_line?(horizontal_line, %{x: point, y: 0})
  end

  defp point_on_horizontal_line?(horizontal_line, point) do
    point.x >= min(horizontal_line.a.x, horizontal_line.b.x) && point.x <= max(horizontal_line.a.x, horizontal_line.b.x)
  end

  defp round(%{a: %{x: x1, y: y1}, b: %{x: x2, y: y2}}) do
    %{a: %{x: Kernel.round(x1), y: Kernel.round(y1)}, b: %{x: Kernel.round(x2), y: Kernel.round(y2)}}
  end

end
