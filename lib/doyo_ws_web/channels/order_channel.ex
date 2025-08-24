defmodule DoyoWsWeb.OrderChannel do
  use DoyoWsWeb, :channel
  require Logger

  @impl true
  def join("order:" <> order_id, _params, socket) do
    send(self(), {:after_join, order_id})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, order_id}, socket) do
    # Fetch cached order from Redis
    case Redix.command(:redix, ["GET", "order_" <> order_id]) do
      {:ok, nil} ->
        :ok

      {:ok, json} ->
        decoded = Jason.decode!(json)
        push(socket, "first_message", decoded)
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


end
