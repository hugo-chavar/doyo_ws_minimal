defmodule DoyoWs.RedisSubscriber do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, conn} = Redix.start_link(name: :redix_pubsub)

    # Subscribe to "orders" channel
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
  def handle_info({:redix_pubsub, _conn, :message, %{channel: "orders", payload: payload}}, state) do
    Logger.debug("Received message from Redis: #{inspect(payload)}")

    case Jason.decode(payload) do
      {:ok, %{"order_id" => order_id} = data} ->
        topic = "order:#{order_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", data)
        Logger.info("Broadcasted to #{topic}: #{inspect(data)}")

      {:error, _reason} ->
        Logger.error("Failed to parse JSON payload: #{payload}")
    end

    {:noreply, state}
  end
end
