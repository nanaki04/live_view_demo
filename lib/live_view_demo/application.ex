defmodule LiveViewDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      # LiveViewDemo.Repo,
      # Start the endpoint when the application starts
      LiveViewDemoWeb.Endpoint,
      # Starts a worker by calling: LiveViewDemo.Worker.start_link(arg)
      # {LiveViewDemo.Worker, arg},
      {Registry, keys: :unique, name: SpaceBirds.State.ArenaRegistry},
      {Registry, keys: :unique, name: SpaceBirds.State.ChatRegistry},
      {Registry, keys: :unique, name: SpaceBirds.State.BackPressureRegistry},
      {Registry, keys: :unique, name: SpaceBirds.State.PreloadRegistry},
      SpaceBirds.State.Players,
      SpaceBirds.State.ArenaSupervisor,
      SpaceBirds.State.ChatSupervisor,
      SpaceBirds.State.BackPressureSupervisor,
      SpaceBirds.State.PreloadSupervisor,
      {Task.Supervisor, name: SpaceBirds.TaskSupervisor.Collision}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveViewDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    LiveViewDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
