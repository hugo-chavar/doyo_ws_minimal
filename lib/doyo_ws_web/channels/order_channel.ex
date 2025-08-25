defmodule DoyoWsWeb.OrderChannel do
  use DoyoWsWeb, :channel
  require Logger

  defp redis_client do
    Application.fetch_env!(:doyo_ws, :redis_impl)
  end

  @impl true
  def join("order:" <> order_id, _params, socket) do
    if valid_object_id?(order_id) do
      Logger.info("JOINED order:#{order_id}")
      send(self(), {:after_join, order_id})
      {:ok, socket}
    else
      Logger.warning("Rejected invalid order_id: #{order_id}")
      {:error, %{reason: "invalid_order_id"}}
    end
  end

  @impl true
  def join(_topic, _params, _socket) do
    {:error, %{reason: "invalid_order_id"}}
  end

  @impl true
  def handle_info({:after_join, order_id}, socket) do
    # Fetch cached order from Redis
    case redis_client().get("json_order_" <> order_id) do
      {:ok, nil} ->
        :ok

      {:ok, json} ->
        decoded = Jason.decode!(json)
        push(socket, "update", decoded)

      {:error, reason} ->
        Logger.error("Redis get failed: #{inspect(reason)}")
        :ok
      end

    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (order:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # -----------------
  # Validation helper
  # -----------------
  defp valid_object_id?(id) when is_binary(id) do
    String.length(id) == 24 and String.match?(id, ~r/\A[0-9a-fA-F]{24}\z/)
  end



end
