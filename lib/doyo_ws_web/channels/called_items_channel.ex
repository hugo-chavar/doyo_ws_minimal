defmodule DoyoWsWeb.CalledItemsChannel do
  use DoyoWsWeb, :channel
  require Logger


  @impl true
  def join("called:" <> restaurant_id, _params, socket) do
      if valid_params?(restaurant_id) do
        # TODO: auth. Check if restaurant exists and user has permission
        {rid, _} = Integer.parse(restaurant_id)
        send(self(), {:after_called_join, rid})
        {:ok, socket}
      else
        Logger.warning("Rejected invalid called items: restaurant_id: #{restaurant_id}")
        {:error, %{reason: "invalid_restaurant"}}
      end
  end

  @impl true
  def handle_info({:after_called_join, restaurant_id}, socket) do
    orders = DoyoWs.OrderService.get_by_restaurant(restaurant_id)
    called_items_detail = OrderSerializer.Aggregator.calculate_called_items(orders)
    push(socket, "update", %{details: called_items_detail})

    {:noreply, socket}
  end

  defp valid_params?(id) when is_binary(id) do
    String.match?(id, ~r/\A[[:digit:]]+\z/)
  end
end
