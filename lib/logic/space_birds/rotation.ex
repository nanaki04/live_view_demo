defmodule SpaceBirds.Logic.Rotation do

  @type t :: number

  def add(r1, r2) do
    case rem(round(as_rotation(r1) + as_rotation(r2)), 360) do
      r when r < 0 -> 360 - r
      r -> r
    end
  end

  def as_rotation(r) when r >= 0 and r <= 360 do
    r
  end

  def as_rotation(r) when r > 0 do
    rem(r, 360)
  end

  def as_rotation(r) do
    360 + rem(r, 360)
  end

end
