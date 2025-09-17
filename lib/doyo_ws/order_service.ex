defmodule DoyoWs.OrderService do
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)
  require Logger

  def get_by_restaurant(restaurant_id) do

    case @redis_client.hvals("orders_#{restaurant_id}") do

      {:ok, order_list} ->
        Enum.map(order_list, &Jason.decode/1)
      {:error, reason} ->
        Logger.error("Error get orders by restaurant id #{restaurant_id}. Reason: #{reason}")
    end

  end

  def get_by_table(restaurant_id, table_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn order -> order["table"]["id"] == table_id end)
  end

  def get_by_orders_id(restaurant_id, order_ids) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn order -> order["_id"] in order_ids end)
  end
end
