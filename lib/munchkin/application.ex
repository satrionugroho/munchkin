defmodule Munchkin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MunchkinWeb.Telemetry,
      Munchkin.Repo,
      {DNSCluster, query: Application.get_env(:munchkin, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Munchkin.PubSub},
      # Start a worker by calling: Munchkin.Worker.start_link(arg)
      # {Munchkin.Worker, arg},
      # Start to serve requests, typically the last entry
      MunchkinWeb.Endpoint,
      Munchkin.DelayedJob,
      Munchkin.Cache,
      Munchkin.Engine,
      Munchkin.Downloader
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Munchkin.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MunchkinWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
