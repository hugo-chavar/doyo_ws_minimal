defmodule DoyoWsWeb.OrderChannel do
  use DoyoWsWeb, :channel

  @impl true
  def join("order:" <> order_id, payload, socket) do
    IO.puts("Join to updates. Order: " <> order_id)
    IO.inspect(payload)
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
