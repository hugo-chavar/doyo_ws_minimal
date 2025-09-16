defmodule DoyoWs.OrderService do
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_by_restaurant(restaurant_id) do

    case @redis_client.hvals("orders_#{restaurant_id}") do

      {:ok, order_list} ->
        restaurant_orders = Enum.map(order_list, &Jason.decode/1)
        {:ok, %{"orders" => restaurant_orders}}
      {:error, reason} ->
        {:error, reason}
    end

  end
end
