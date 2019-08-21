defmodule SpaceBirds.Logic.Vector2 do
  alias SpaceBirds.Logic.Math
  alias SpaceBirds.Logic.Rotation
  import Kernel, except: [min: 2, max: 2, abs: 1]

  @type t :: %{
    x: number,
    y: number
  }

  defstruct x: 0,
    y: 0

  def new(x, y) do
    %__MODULE__{x: x, y: y}
  end

  @spec from_rotation(Rotation.t) :: t
  def from_rotation(rotation) do
    new(
      Math.sin(rotation),
      # MEMO html is from top to bottom, so we have to invert the y axis
      -Math.cos(rotation)
    )
  end

  @spec to_rotation(t) :: Rotation.t
  def to_rotation(v2) do
    # MEMO html is from top to bottom, so we have to invert the y axis
    rem(round(Math.atan2(v2.x, -v2.y)) + 360, 360)
  end

  @spec mul(t, t | number) :: t
  def mul(v2, %{x: x, y: y}) do
    new(
      v2.x * x,
      v2.y * y
    )
  end

  def mul(v2, x) when is_number(x) do
    new(v2.x * x, v2.y * x)
  end

  @spec div(t, t | number) :: t
  def div(v2, %{x: x, y: y}) do
    new(v2.x / x, v2.y / y)
  end

  def div(v2, x) when is_number(x) do
    new(v2.x / x, v2.y / x)
  end

  @spec add(t, t | number) :: t
  def add(v2, %{x: x, y: y}) do
    new(v2.x + x, v2.y + y)
  end

  def add(v2, x) when is_number(x) do
    new(v2.x + x, v2.y + x)
  end

  @spec sub(t, t | number) :: t
  def sub(v2, %{x: x, y: y}) do
    new(v2.x - x, v2.y - y)
  end

  def sub(v2, x) do
    new(v2.x - x, v2.y - x)
  end

  @spec min(t, t | number) :: t
  def min(v2, %{x: x, y: y}) do
    new(Kernel.min(v2.x, x), Kernel.min(v2.y, y))
  end

  def min(v2, x) when is_number(x) do
    new(Kernel.min(v2.x, x), Kernel.min(v2.y, x))
  end

  @spec max(t, t | number) :: t
  def max(v2, %{x: x, y: y}) do
    new(Kernel.max(v2.x, x), Kernel.max(v2.y, y))
  end

  def max(v2, x) when is_number(x) do
    new(Kernel.max(v2.x, x), Kernel.max(v2.y, x))
  end

  @spec distance(t) :: number
  def distance(v2) do
    :math.sqrt(:math.pow(v2.x, 2) + :math.pow(v2.y, 2))
  end

  @spec abs(t) :: t
  def abs(v2) do
    new(Kernel.abs(v2.x), Kernel.abs(v2.y))
  end

end
