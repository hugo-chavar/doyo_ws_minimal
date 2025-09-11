defmodule DoyoWs.RedisMessageRouter do
  require Logger

  def route("orders", payload) do
    case Jason.decode(payload) do
      {:ok, %{"order_id" => order_id, "data" => inner_data}} when is_binary(order_id) ->
        topic = "order:#{order_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", inner_data)
        Logger.info("Broadcasted to #{topic}: #{inspect(inner_data)}")

      {:ok, decoded} ->
        Logger.warning("Received orders message without order_id: #{inspect(decoded)}")

      {:error, reason} ->
        Logger.error("Failed to decode order message: #{inspect(reason)} - #{payload}")
    end
  end

  def route("table_details", payload) do
    # Add logic for table_details later
    Logger.info("Stub: Received table_details payload #{payload}")
  end

  def route("department_details", payload) do
    # Add logic for department_details later
    Logger.info("Stub: Received department_details payload #{payload}")
  end

  def route("counter_" <> type, payload) do
    {:ok, %{"rid" => restaurant_id}} = Jason.decode(payload)
    Logger.info("Stub: Received #{type}_counter for restaurant #{restaurant_id}")
    case DoyoWs.OrderItemCounter.get_counter(restaurant_id, type) do
      {:ok, count} ->
        topic = "counter:#{type}:#{restaurant_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", count)
        Logger.info("Broadcasted to #{topic}: #{count}")
      counter_response ->
        Logger.info("Problem to get counter: #{inspect(counter_response)}")

    end

  end

  def route(channel, payload) do
    Logger.warning("No handler defined for channel #{channel}, payload: #{payload}")
  end
end
