defmodule SpaceBirds.Logic.ProgressOverTime do
  alias SpaceBirds.Logic.Math

  @type t :: %{
    from: number,
    to: number
  }

  defstruct from: 0,
    to: 0

  def linear(%{from: from, to: to}, progress) do
    progress = progress
               |> min(1)
               |> max(0)

    from + (to - from) * progress
  end

  def sine_curve(%{from: from, to: to}, progress) do
    progress = progress
               |> min(1)
               |> max(0)
               |> Kernel.*(90)
               |> Math.sin

    from + (to - from) * progress
  end

  def inverse_sine_curve(%{from: from, to: to}, progress) do
    progress = progress
               |> min(1)
               |> max(0)
               |> (&(1 - &1)).()
               |> Kernel.*(90)
               |> Math.sin
               |> (&(1 - &1)).()

    from + (to - from) * progress
  end

  def exponential(%{from: from, to: to}, progress) do
    progress = progress
               |> min(1)
               |> max(0)
               |> :math.pow(2)

    from + (to - from) * progress
  end

  def inverse_exponential(%{from: from, to: to}, progress) do
    progress = progress
               |> min(1)
               |> max(0)
               |> :math.pow(2)
               |> (&(1 - &1)).()

    from + (to - from) * progress
  end

end
