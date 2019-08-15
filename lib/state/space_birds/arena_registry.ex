defmodule SpaceBirds.State.ArenaRegistry do

  def list_all() do
    Registry.select(SpaceBirds.State.ArenaRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

end
