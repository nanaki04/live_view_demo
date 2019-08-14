defmodule SpaceBirds.Logic.Position do

  @type t :: %{
    x: number,
    y: number
  }

  defstruct x: 0,
    y: 0

  def new(x, y), do: %__MODULE__{x: x, y: y}

  def new([x, y]), do: new(x, y)

end
