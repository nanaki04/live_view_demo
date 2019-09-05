defmodule SpaceBirds.Logic.Color do
  alias __MODULE__
  use SpaceBirds.Utility.MapAccess

  @type t :: %{
    r: number,
    g: number,
    b: number,
    a: number
  }

  @type gradient :: %{
    from: t,
    to: t
  }

  defstruct r: 0,
    g: 0,
    b: 0,
    a: 0

  @spec white() :: t
  def white() do
    %Color{r: 255, g: 255, b: 255, a: 255}
  end

  @spec black() :: t
  def black() do
    %Color{r: 0, g: 0, b: 0, a: 255}
  end

  @spec to_hex(t) :: String.t
  def to_hex(%{r: r, g: g, b: b, a: _a}) do
    # TODO handle transparancy
    "#"
    <> String.pad_leading(Integer.to_string(r, 16), 2, "0")
    <> String.pad_leading(Integer.to_string(g, 16), 2, "0")
    <> String.pad_leading(Integer.to_string(b, 16), 2, "0")
  end

  @spec to_opacity(t) :: number
  def to_opacity(%{a: a}) do
    a / 255
  end

  @spec new_gradient(t, t) :: gradient
  def new_gradient(from, to) do
    %{
      from: from,
      to: to
    }
  end

  @spec get_color_on_gradient(gradient, number) :: t
  def get_color_on_gradient(%{from: from, to: to}, value) do
    %Color{
      r: round(from.r + ((to.r - from.r) * value))
         |> min(255)
         |> max(0),
      g: round(from.g + ((to.g - from.g) * value))
         |> min(255)
         |> max(0),
      b: round(from.b + ((to.b - from.b) * value))
         |> min(255)
         |> max(0),
      a: round(from.a + ((to.a - from.a) * value))
         |> min(255)
         |> max(0)
    }
  end

end
