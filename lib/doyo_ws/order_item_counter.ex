defmodule DoyoWs.OrderItemCounter do

  def get_counter(restaurant_id, counter_type) do
      count =
        DoyoWs.OrderService.get_by_restaurant(restaurant_id)
        |> Enum.reduce(0, fn order, total_count ->
            case order do
              {:ok, %{"t" => t, "active" => true, "completed" => false, "items" => items}} ->
                if String.downcase(t) == String.downcase(counter_type) do
                  item_count = Enum.count(items, fn item -> item["completed"] == false end)
                  total_count + item_count
                else
                  total_count
                end
              {:ok, _payload} ->
                total_count
            end
          end)
      {:ok, %{"count" => count}}

  end
end
