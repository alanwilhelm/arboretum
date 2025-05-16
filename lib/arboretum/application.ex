defmodule Arboretum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ArboretumWeb.Telemetry,
      Arboretum.Repo,
      {DNSCluster, query: Application.get_env(:arboretum, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Arboretum.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Arboretum.Finch},
      # Start the Registry for dynamic agents
      {Registry, keys: :unique, name: Arboretum.AgentRegistry},
      # Start the DynamicSupervisor for agent processes
      {DynamicSupervisor, name: Arboretum.AgentDynamicSupervisor, strategy: :one_for_one},
      # Start the AgentServerManager
      {Arboretum.Agents.AgentServerManager, []},
      # Start the BatchResults manager
      {Arboretum.BatchResults, []},
      # Start a worker by calling: Arboretum.Worker.start_link(arg)
      # {Arboretum.Worker, arg},
      # Start to serve requests, typically the last entry
      ArboretumWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Arboretum.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ArboretumWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
