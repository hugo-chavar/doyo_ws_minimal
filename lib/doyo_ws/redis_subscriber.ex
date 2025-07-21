defmodule DoyoWs.RedisSubscriber do
  use GenServer
  require Logger

  @redis_channels ["orders"] # , "table_details", "department_details", "pos_counter"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    redis_host = System.get_env("REDIS_HOST") || "redis"
    redis_port = String.to_integer(System.get_env("REDIS_PORT") || "6379")
    Logger.info("Connecting to Redis at #{redis_host}:#{redis_port}")

    {:ok, conn} =
      Redix.PubSub.start_link(
        host: redis_host,
        port: redis_port,
        name: :redix_pubsub
      )

    send(self(), :subscribe)

    {:ok, %{conn: conn}}
  end

  @impl true
  def handle_info(:subscribe, state) do
    Enum.each(@redis_channels, fn channel ->
      {:ok, _ref} = Redix.PubSub.subscribe(state.conn, channel, self())
      Logger.info("Subscribed to Redis channel: #{channel}")
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _conn, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.debug("Received message from Redis [#{channel}]: #{inspect(payload)}")

    DoyoWs.RedisMessageRouter.route(channel, payload)

    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _conn, _ref, :subscribed, %{channel: channel}}, state) do
    Logger.debug("Subscribed to #{channel}")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
end
