defmodule DoyoWs.DepartmentDetails do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_details(restaurant_id, department_id) do
    case @redis_client.hvals("orders_#{restaurant_id}") do
      {:ok, order_list} ->
        {table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys_with_dept_items} =
          Enum.reduce(order_list, {%{}, %{}, %{}, %{}, %{}, %{pending: 0, called: 0, delivered: 0, deleted: 0}, MapSet.new()}, fn order_str, acc ->
            case Jason.decode(order_str) do
              {:ok, order} ->
                process_order(order, department_id, acc)
              {:error, reason} ->
                Logger.error("Failed to decode order: #{reason}")
                acc
            end
          end)

        # Filter table_data and add item lists
        filtered_table_data =
          table_data
          |> Enum.filter(fn {key, _} -> MapSet.member?(table_keys_with_dept_items, key) end)
          |> Enum.map(fn {key, value} ->
            value
            |> Map.put(:pending_items, [%{items: Map.get(pending_items, key, [])}])
            |> Map.put(:called_items, Map.get(called_items, key, %{}) |> Map.values())
            |> Map.put(:ready_items, Map.get(ready_items, key, %{}) |> Map.values())
            |> Map.put(:delivered_items, Map.get(delivered_items, key, %{}) |> Map.values())
          end)

        result = %{
          tables: filtered_table_data,
          delivered_items: counts.delivered,
          called_items: counts.called,
          pending_items: counts.pending,
          deleted_items: counts.deleted
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_order(order, department_id, {table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys}) do
    table_data_key = "#{order["table_order"]["name"]} #{order["menu"]["title"]}"
    order_id = order["_id"]
    order_counter = order["order_counter"]
    order_type = order["order_type"]
    order_estimated_preparation_time = order["estimated_preparation_time"] || 0

    {is_delivery, is_takeaway} = {order_type == "MenuDelivery", order_type == "MenuTakeAway"}

    {delivery_status, assigned_driver_id, estimated_delivery_time, delivery_details} =
      if is_delivery or is_takeaway do
        {
          order["delivery_status"],
          if(is_delivery, do: order["assigned_driver_id"], else: nil),
          if(is_delivery, do: order["estimated_delivery_time"], else: nil),
          if(is_delivery, do: order["delivery"], else: nil)
        }
      else
        {nil, nil, nil, nil}
      end

    # Initialize table data if not exists
    table_data =
      if not Map.has_key?(table_data, table_data_key) do
        Map.put(table_data, table_data_key, %{
          name: table_data_key,
          table_id: order["table_order"]["id"],
          order_datetime: order["timestamp"],
          no_of_guests: get_guests(order["restaurant"]["id"], order["table_order"]["id"])
        })
      else
        table_data
      end

    # Update order datetime if this order is older
    table_data =
      if order["timestamp"] < table_data[table_data_key].order_datetime do
        put_in(table_data, [table_data_key, :order_datetime], order["timestamp"])
      else
        table_data
      end

    # Process items
    {has_dept_items, new_pending, new_called, new_ready, new_delivered, new_counts} =
      Enum.reduce(order["items"], {false, pending_items, called_items, ready_items, delivered_items, counts}, fn item, {has_items, pend, call, ready, deliv, cnt} ->
        process_item(item, order_id, order_counter, order_type, order_estimated_preparation_time,
                    delivery_status, assigned_driver_id, estimated_delivery_time, delivery_details,
                    department_id, table_data_key, {has_items, pend, call, ready, deliv, cnt})
      end)

    # Update table keys if this order has department items
    table_keys =
      if has_dept_items do
        MapSet.put(table_keys, table_data_key)
      else
        table_keys
      end

    {table_data, new_pending, new_called, new_ready, new_delivered, new_counts, table_keys}
  end

  defp process_item(item, order_id, order_counter, order_type, estimated_preparation_time,
                   delivery_status, assigned_driver_id, estimated_delivery_time, delivery_details,
                   department_id, table_data_key, {has_items, pend, call, ready, deliv, cnt}) do
    # Enhance item with order information
    enhanced_item = item
      |> Map.put("order_id", order_id)
      |> Map.put("order_counter", order_counter)
      |> Map.put("order_type", order_type)
      |> Map.put("estimated_preparation_time", estimated_preparation_time)
      |> then(fn item ->
        if delivery_status do
          item
          |> Map.put("delivery_status", delivery_status)
          |> Map.put("assigned_driver_id", assigned_driver_id)
          |> Map.put("estimated_delivery_time", estimated_delivery_time)
          |> Map.put("delivery", delivery_details)
        else
          item
        end
      end)

    dept = get_in(item, ["product", "category", "department"])
    user_order_action_status = item["user_order_action_status"]
    current_status = user_order_action_status["current"]["status"]

    if dept["id"] == department_id do
      case current_status do
        "Pending" ->
          new_pend = update_in(pend, [table_data_key], fn existing -> (existing || []) ++ [enhanced_item] end)
          {true, new_pend, call, ready, deliv, update_count(cnt, :pending, 1)}

        "Called" ->
          username = user_order_action_status["current"]["user"]["username"]
          new_call = update_user_items(call, table_data_key, username, enhanced_item)
          {true, pend, new_call, ready, deliv, update_count(cnt, :called, 1)}

        "Ready" ->
          username = user_order_action_status["current"]["user"]["username"]
          new_ready = update_user_items(ready, table_data_key, username, enhanced_item)
          {true, pend, call, new_ready, deliv, cnt}

        "Delivered" ->
          username = user_order_action_status["current"]["user"]["username"]
          new_deliv = update_user_items(deliv, table_data_key, username, enhanced_item)
          {true, pend, call, ready, new_deliv, update_count(cnt, :delivered, 1)}

        "Deleted" ->
          process_deleted_item(user_order_action_status, enhanced_item, table_data_key,
                              {has_items, pend, call, ready, deliv, cnt})

        _ ->
          {has_items, pend, call, ready, deliv, cnt}
      end
    else
      {has_items, pend, call, ready, deliv, cnt}
    end
  end

  defp process_deleted_item(user_order_action_status, item, table_data_key, {has_items, pend, call, ready, deliv, cnt}) do
    if user_order_action_status["history"] do
      last_status = List.last(user_order_action_status["history"])
      username = last_status["user"]["username"]

      case last_status["status"] do
        "Pending" ->
          new_pend = update_in(pend, [table_data_key], fn existing -> (existing || []) ++ [item] end)
          {true, new_pend, call, ready, deliv, update_count(cnt, :deleted, 1)}

        "Called" ->
          new_call = update_user_items(call, table_data_key, username, item)
          {true, pend, new_call, ready, deliv, update_count(cnt, :deleted, 1)}

        "Ready" ->
          new_ready = update_user_items(ready, table_data_key, username, item)
          {true, pend, call, new_ready, deliv, update_count(cnt, :deleted, 1)}

        "Delivered" ->
          new_deliv = update_user_items(deliv, table_data_key, username, item)
          {true, pend, call, ready, new_deliv, update_count(cnt, :deleted, 1)}

        _ ->
          {has_items, pend, call, ready, deliv, update_count(cnt, :deleted, 1)}
      end
    else
      {has_items, pend, call, ready, deliv, update_count(cnt, :deleted, 1)}
    end
  end

  defp update_user_items(items_map, table_key, username, item) do
    update_in(items_map, [table_key, username], fn user_data ->
      if user_data do
        update_in(user_data, ["items"], fn existing -> existing ++ [item] end)
      else
        %{"username" => username, "items" => [item]}
      end
    end)
  end

  defp update_count(counts, key, increment) do
    Map.update(counts, key, increment, &(&1 + increment))
  end

  defp get_guests(restaurant_id, table_id) do
    # Assuming this function is implemented in another module
    DoyoWs.TableReservation.get_guests(restaurant_id, table_id)
  end
end
