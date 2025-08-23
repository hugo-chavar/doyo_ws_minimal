defmodule DoyoWs.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    redis_host = System.get_env("REDIS_HOST") || "redis"
    redis_port = String.to_integer(System.get_env("REDIS_PORT") || "6379")

    children = [
      DoyoWsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:doyo_ws, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DoyoWs.PubSub},
      DoyoWsWeb.Endpoint,
      # Command connection (this one supports child_spec/1)
      {Redix, [host: redis_host, port: redis_port, name: :redix]},
      # PubSub connection (manual child spec, since Redix.PubSub lacks child_spec/1)
      %{
        id: Redix.PubSub,
        start: {Redix.PubSub, :start_link, [[host: redis_host, port: redis_port, name: :redix_pubsub]]}
      },
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
