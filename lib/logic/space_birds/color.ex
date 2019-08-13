defmodule SpaceBirds.Logic.Color do

  @type t :: %{
    r: number,
    g: number,
    b: number,
    a: number
  }

  defstruct r: 0,
    g: 0,
    b: 0,
    a: 0

  def to_hex(%{r: r, g: g, b: b, a: a}) do
    "#"
    <> Integer.to_string(r, 16)
    <> Integer.to_string(g, 16)
    <> Integer.to_string(b, 16)
  end

end
