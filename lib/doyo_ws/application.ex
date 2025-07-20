defmodule DoyoWs.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DoyoWsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:doyo_ws, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DoyoWs.PubSub},
      DoyoWsWeb.Endpoint,
      {Redix, name: :redix},
      DoyoWs.RedisSubscriber
    ]

    opts = [strategy: :one_for_one, name: DoyoWs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DoyoWsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
