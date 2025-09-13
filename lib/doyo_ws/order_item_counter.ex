defmodule DoyoWs.OrderItemCounter do
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_counter(restaurant_id, counter_type) do

    case @redis_client.hvals("orders_#{restaurant_id}") do

      {:ok, order_list} ->
        count = Enum.reduce(order_list, 0, fn order_str, total_count ->
          case Jason.decode(order_str) do
            {:ok, %{"id" => _id, "c" => item_count, "t" => t}} ->
              if String.downcase(t) == String.downcase(counter_type) do
                total_count + item_count
              else
                total_count
              end
            {:ok, _payload} ->
              total_count
          end
        end)
        {:ok, %{"count" => count}}
      {:error, reason} ->
        {:error, reason}
    end

  end
end
