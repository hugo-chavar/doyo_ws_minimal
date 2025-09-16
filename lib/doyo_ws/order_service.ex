defmodule DoyoWs.OrderService do
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_by_restaurant(restaurant_id) do

    case @redis_client.hvals("orders_#{restaurant_id}") do

      {:ok, order_list} ->
        Enum.map(order_list, &Jason.decode/1)
      {:error, reason} ->
        {:error, reason}
    end

  end

  def get_by_table(restaurant_id, table_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn order -> order["table"]["id"] == table_id end)
  end
end
