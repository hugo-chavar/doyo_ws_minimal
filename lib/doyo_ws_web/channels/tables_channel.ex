defmodule DoyoWsWeb.TablesChannel do
  use DoyoWsWeb, :channel
  require Logger


  @impl true
  def join("tables:" <> restaurant_id, _params, socket) do
      if valid_params?(restaurant_id) do
        # TODO: Check if restaurant exists and user has permission
        {rid, _} = Integer.parse(restaurant_id)
        send(self(), {:after_tables_join, rid})
        {:ok, socket}
      else
        Logger.warning("Rejected invalid tables: restaurant_id: #{restaurant_id}")
        {:error, %{reason: "invalid_restaurant"}}
      end
  end

  @impl true
  def handle_info({:after_tables_join, restaurant_id}, socket) do
    orders = DoyoWs.OrderService.get_by_restaurant(restaurant_id)
    all_tables_detail = OrderSerializer.serialize_all_tables(orders)
    push(socket, "update", all_tables_detail)

    {:noreply, socket}
  end

  defp valid_params?(id) when is_binary(id) do
    String.match?(id, ~r/\A[[:digit:]]+\z/)
  end
end
