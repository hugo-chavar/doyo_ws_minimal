defmodule DoyoWs.OrderItemCounter do
  alias OrderSerializer.Order

  def get_counter(restaurant_id, counter_type) do
    count =
      DoyoWs.OrderService.get_by_restaurant(restaurant_id)
      |> Enum.reduce(0, fn order, total_count ->
        case order do
          %Order{t: type, active: true, completed: false, items: items} ->
            if String.downcase(type) == String.downcase(counter_type) do
              item_count = Enum.count(items, fn item ->
                not item.completed
              end)
              total_count + item_count
            else
              total_count
            end
          _ ->
            total_count
        end
      end)
      {:ok, %{count: count}}

  end
end
