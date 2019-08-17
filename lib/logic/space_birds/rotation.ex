defmodule SpaceBirds.Logic.Rotation do

  @type t :: number

  def add(r1, r2) do
    case rem(round(r1 + r2), 360) do
      r when r < 0 -> 360 - r
      r -> r
    end
  end

end
