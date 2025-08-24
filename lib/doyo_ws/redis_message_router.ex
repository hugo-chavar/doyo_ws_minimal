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

  def route("pos_counter", payload) do
    # Add logic for pos_counter later
    Logger.info("Stub: Received pos_counter payload #{payload}")
  end

  def route(channel, payload) do
    Logger.warning("No handler defined for channel #{channel}, payload: #{payload}")
  end
end
