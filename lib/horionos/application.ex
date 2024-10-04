defmodule Horionos.Application do
  @moduledoc """
  OTP Application specification for Horionos
  """

  use Application

  @impl Application
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    children = [
      HorionosWeb.Telemetry,
      Horionos.Repo,
      {DNSCluster, query: Application.get_env(:horionos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Horionos.PubSub},
      {Finch, name: Horionos.Finch},
      {Oban, Application.fetch_env!(:horionos, Oban)},
      Horionos.Services.RateLimiter,
      HorionosWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Horionos.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    HorionosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
