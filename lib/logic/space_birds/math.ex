defmodule SpaceBirds.Logic.Math do

  @spec sin(number) :: number
  def sin(n) do
    :math.sin(n / (180 / :math.pi))
  end

  @spec cos(number) :: number
  def cos(n) do
    :math.cos(n / (180 / :math.pi))
  end

  @spec asin(number) :: number
  def asin(n) do
    n
    |> min(1)
    |> max(-1)
    |> :math.asin
    |> Kernel.*(180 / :math.pi)
  end

  @spec atan2(number, number) :: number
  def atan2(x, y) do
    :math.atan2(x, y) * (180 / :math.pi)
  end

end
