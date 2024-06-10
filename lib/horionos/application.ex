defmodule Horionos.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HorionosWeb.Telemetry,
      Horionos.Repo,
      {DNSCluster, query: Application.get_env(:horionos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Horionos.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Horionos.Finch},
      # Start a worker by calling: Horionos.Worker.start_link(arg)
      # {Horionos.Worker, arg},
      # Start to serve requests, typically the last entry
      HorionosWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Horionos.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HorionosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
