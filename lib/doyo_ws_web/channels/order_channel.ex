defmodule DoyoWsWeb.OrderChannel do
  use DoyoWsWeb, :channel
  require Logger

  @impl true
  def join("order:" <> order_id, _payload, socket) do
    Logger.info("Join to updates. Order: #{order_id}")

    # Try to fetch cached "first message" from Redis
    case Redix.command(:redix, ["GET", "order_#{order_id}"]) do
      {:ok, nil} ->
        Logger.debug("No cached message for order: #{order_id}")

      {:ok, cached} ->
        with {:ok, decoded} <- Jason.decode(cached) do
          Logger.debug("Sending cached first message for order #{order_id}: #{inspect(decoded)}")
          push(socket, "first_message", decoded)
        else
          _ -> Logger.error("Failed to decode cached message for #{order_id}")
        end

      {:error, reason} ->
        Logger.error("Redis GET failed for order #{order_id}: #{inspect(reason)}")
    end

    {:ok, %{}, socket}
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


end
