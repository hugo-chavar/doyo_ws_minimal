defmodule DoyoWs.RedisSubscriber do
  use GenServer
  require Logger

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
    {:ok, _subscription_ref} = Redix.PubSub.subscribe(state.conn, "orders", self())
    Logger.info("Subscribed to Redis channel: orders")
    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _conn, _ref, :subscribed, %{channel: "orders"}}, state) do
    Logger.debug("Successfully subscribed to 'orders'")
    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _conn, _ref, :message, %{channel: "orders", payload: payload}}, state) do
    Logger.debug("Received message from Redis: #{inspect(payload)}")

    case Jason.decode(payload) do
      {:ok, %{"order_id" => order_id} = data} ->
        topic = "order:#{order_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", data)
        Logger.info("Broadcasted to #{topic}: #{inspect(data)}")

      {:error, reason} ->
        Logger.error("Failed to parse JSON: #{inspect(reason)} - Payload: #{payload}")
    end

    {:noreply, state}
  end

  # Optional: catch-all
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
end
