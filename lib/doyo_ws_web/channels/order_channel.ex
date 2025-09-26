defmodule DoyoWsWeb.OrderChannel do
  use DoyoWsWeb, :channel
  require Logger

  @impl true
  def join("order:" <> rest, _params, socket) do
    case String.split(rest, ":", parts: 2) do
      [restaurant_id, order_id] ->
        if valid_params?(restaurant_id, order_id) do
          # TODO: auth. Check if restaurant exists and user has permission
          Logger.info("JOINED order#{restaurant_id}:#{order_id}")
          {rid, _} = Integer.parse(restaurant_id)
          send(self(), {:after_join, rid, order_id})
          {:ok, socket}
        else
          Logger.warning("Rejected invalid params: #{restaurant_id}, #{order_id}")
          {:error, %{reason: "invalid_params_format"}}
        end
      _ ->
        Logger.warning("Invalid counter topic format: #{rest}")
        {:error, %{reason: "invalid_format"}}
    end
  end

  @impl true
  def join(_topic, _params, _socket) do
    {:error, %{reason: "invalid_order_id"}}
  end

  @impl true
  def handle_info({:after_join, restaurant_id, order_id}, socket) do
    order = DoyoWs.OrderService.get_by_order_id(restaurant_id, order_id)
    push(socket, "update", order)
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
  defp valid_params?(restaurant_id , order_id) when is_binary(order_id) do
    String.match?(restaurant_id, ~r/\A[[:digit:]]+\z/) and String.length(order_id) == 24 and String.match?(order_id, ~r/\A[0-9a-fA-F]{24}\z/)
  end

end
