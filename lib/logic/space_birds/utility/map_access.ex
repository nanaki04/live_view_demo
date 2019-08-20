defmodule SpaceBirds.Utility.MapAccess do

  defmacro __using__(_opts) do
    quote do
      @behaviour Access

      @impl(Access)
      def fetch(data, key) do
        Map.fetch(data, key)
      end

      @impl(Access)
      def get_and_update(data, key, update) do
        Map.get_and_update(data, key, update)
      end

      @impl(Access)
      def pop(data, key) do
        Map.pop(data, key)
      end
    end
  end

end
