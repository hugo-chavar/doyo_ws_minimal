defmodule DoyoWs.Order do

  def enhance(order) do
    order_type = order["order_type"]
    is_delivery = order_type == "MenuDelivery"
    is_takeaway = order_type == "MenuTakeAway"

    enhanced_items = Enum.map(order["items"], fn item ->
      enhance_item(item, order, is_delivery, is_takeaway)
    end)

    Map.put(order, "items", enhanced_items)
  end

  defp enhance_item(item, order, is_delivery, is_takeaway) do
    item
    |> Map.put("order_id", order["_id"])
    |> Map.put("order_counter", order["order_counter"])
    |> Map.put("order_type", order["order_type"])
    |> Map.put("estimated_preparation_time", order["estimated_preparation_time"] || 0)
    |> then(fn item ->
      if is_delivery or is_takeaway do
        item
        |> Map.put("delivery_status", order["delivery_status"])
        |> then(fn item ->
          if is_delivery do
            item
            |> Map.put("assigned_driver_id", order["assigned_driver_id"])
            |> Map.put("estimated_delivery_time", order["estimated_delivery_time"])
            |> Map.put("delivery", order["delivery"])
          else
            item
          end
        end)
      else
        item
      end
    end)
  end

end
