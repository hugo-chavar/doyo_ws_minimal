defmodule DoyoWs.RedisSubscriber do
  use GenServer
  require Logger

  @redis_channels ["orders", "counter_pos", "counter_kiosk", "order_items_update", "guests_update"]
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    send(self(), :subscribe)
    {:ok, %{conn: :redix_pubsub}}
  end

  @impl true
  def handle_info(:subscribe, state) do
    Enum.each(@redis_channels, fn channel ->
      {:ok, _ref} = @redis_client.subscribe(channel)
      Logger.info("Subscribed to Redis channel: #{channel}")
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _conn, _ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.debug("Received message from Redis [#{channel}]: #{inspect(payload)}")

    Task.start(fn ->
      try do
        with {:ok, decoded} <- JSON.decode(payload) do
          # :telemetry.execute([:doyo_ws, :redis_message, :processing], %{count: 1}, %{channel: channel})
          DoyoWs.RedisMessageRouter.route(channel, decoded)
        else
          {:error, error} ->
            Logger.error("Invalid message on #{channel}: #{inspect(error)}")
            # :telemetry.execute([:doyo_ws, :redis_message, :validation_error], %{count: 1}, %{channel: channel})
        end
      rescue
        error ->
          Logger.error("CRITICAL: Failed to process Redis message on #{channel}: #{inspect(error)}")
          Logger.error("Payload: #{inspect(payload)}")
          # :telemetry.execute([:doyo_ws, :redis_message, :processing_error], %{count: 1}, %{channel: channel})
          # MyErrorReporter.report(error, payload, channel)
      end
    end)
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
