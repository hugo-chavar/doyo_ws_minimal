defmodule DoyoWs.RedisMessageRouter do
  require Logger

  def route("orders", payload) do
    case Jason.decode(payload) do
      {:ok, %{"order_id" => order_id} = data} ->
        topic = "order:#{order_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", data)
        Logger.info("Broadcasted to #{topic}: #{inspect(data)}")

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
