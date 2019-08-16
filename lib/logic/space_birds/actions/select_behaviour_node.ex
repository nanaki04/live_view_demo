defmodule SpaceBirds.Actions.SelectBehaviourNode do
  alias SpaceBirds.Behaviour.Node

  @type t :: %{
    node: Node.t
  }

  defstruct node: %Node{}

end
