defmodule SpaceBirds.Logic.Rotation do

  @type t :: number

  def add(r1, r2) do
    case rem(round(as_rotation(r1) + as_rotation(r2)), 360) do
      r when r < 0 -> 360 - r
      r -> r
    end
  end

  def subtract(r1, r2) do
    round(as_rotation(r1) - as_rotation(r2))
    |> as_rotation
  end

  def as_rotation(r) when r >= 0 and r <= 360 do
    round(r)
  end

  def as_rotation(r) when r > 0 do
    rem(round(r), 360)
  end

  def as_rotation(r) do
    360 + rem(round(r), 360)
  end

  def distance(r1) do
    distance(r1, 0)
  end

  def distance(180, 0), do: 180

  def distance(r1, 0) when r1 > 180 do
    360 - as_rotation(r1)
  end

  def distance(r1, 0) when r1 < 180 do
    as_rotation(r1)
  end

  def distance(r1, r2) do
    subtract(r1, r2)
    |> distance
  end

end
