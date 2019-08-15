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

  def to_hex(%{r: r, g: g, b: b, a: _a}) do
    # TODO handle transparancy
    "#"
    <> String.pad_leading(Integer.to_string(r, 16), 2, "0")
    <> String.pad_leading(Integer.to_string(g, 16), 2, "0")
    <> String.pad_leading(Integer.to_string(b, 16), 2, "0")
  end

end
