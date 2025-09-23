defmodule DoyoWs.OrderService do
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)
  require Logger
  alias OrderSerializer.DataMapper

  def get_by_restaurant(restaurant_id) do
    case @redis_client.hvals("orders_#{restaurant_id}") do
      {:ok, order_list} ->
        order_list
        |> Enum.map(&Jason.decode/1)
        |> Enum.filter(fn
          {:ok, _order} -> true
          {:error, reason} ->
            Logger.info("get_by_restaurant Error decoding order: #{reason}")
            false
        end)
        |> Enum.map(fn {:ok, order} -> DoyoWs.Order.enhance(order) end)
        |> Enum.map(fn order -> DataMapper.map_order(order) end)

      {:error, reason} ->
        Logger.error("Error get orders by restaurant id #{restaurant_id}. Reason: #{reason}")
    end
  end

  def get_by_table(restaurant_id, table_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn order -> order.table_order.id == table_id end)
  end

  def get_by_orders_id(restaurant_id, order_ids) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn order -> order._id in order_ids end)
  end

  def get_by_order_id(restaurant_id, order_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.find(fn order -> order._id == order_id end)
  end

end
