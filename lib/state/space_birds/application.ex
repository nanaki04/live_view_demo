defmodule SpaceBirds.State.Application do

  @type location :: :main_menu
    | :arena
    | :result

  @type application_state :: %__MODULE__{
    location: location
  }

  defstruct location: :main_menu

end
