defmodule DoyoWs.DepartmentDetails do
  require Logger
  alias DoyoWs.OrderService

  # Public API for different update scenarios
  def get_full_department_details(restaurant_id, department_id) do
    OrderService.get_by_restaurant(restaurant_id)
    |> process_all_orders(department_id)
  end

  def handle_guests_update(restaurant_id, table_order, menu, table_id) do
    OrderService.get_by_table(restaurant_id, table_id)
    |> process_guests_update(table_order, menu, restaurant_id, table_id)
  end

  def handle_item_action(restaurant_id, table_order, menu, order_items, action) do
    process_item_action(table_order, menu, order_items, action, restaurant_id)
  end

  def handle_item_delete(restaurant_id, table_order, menu, deleted_items) do
    OrderService.get_by_orders_id(restaurant_id, Enum.map(deleted_items, & &1["order_id"]))
    |> process_item_delete(table_order, menu, deleted_items, restaurant_id)
  end

  def handle_item_edit(restaurant_id, table_order, menu, order_items) do
    process_item_edit(table_order, menu, order_items, restaurant_id)
  end

  def handle_item_sent_back(restaurant_id, table_order, menu, sent_back_items) do
    OrderService.get_by_orders_id(restaurant_id, Enum.map(sent_back_items, & &1["order_id"]))
    |> process_item_sent_back(table_order, menu, sent_back_items, restaurant_id)
  end

  def handle_new_order(restaurant_id, order) do
    process_new_order(order, restaurant_id)
  end

  # Private implementation
  defp process_all_orders(order_list, department_id) do
    {table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys} =
      Enum.reduce(order_list, initial_state(), fn order, acc ->
        process_order(order, department_id, acc)
      end)

    result = build_final_result(table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys)
    {:ok, result}
  end

  defp process_guests_update(orders, table_order, menu, restaurant_id, _table_id) do
    table_data_key = build_table_key(table_order, menu)

    items_by_dept =
      orders
      |> Enum.flat_map(& &1["items"])
      |> Enum.filter(fn item -> not item["completed"] end)
      |> group_items_by_department

    # Return payload grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, _items}, acc ->
      response_data = %{
        "tables" => [
          %{
            "name" => table_data_key,
            "table_id" => table_order["id"],
            "data" => %{}, # Assuming this comes from another module
            "update_guests" => true
          }
        ]
      }
      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  defp process_item_action(table_order, menu, order_items, action, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    user_order_action_status = hd(order_items)["user_order_action_status"]
    user = get_in(user_order_action_status, ["current", "user"])
    username = if user, do: user["username"], else: nil
    time = user_order_action_status["current"]["timestamp"]

    items_by_dept = group_items_by_department(order_items)

    # Build response data grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, items}, acc ->
      response_data = build_action_response(action, table_data_key, table_order, username, time, items)
      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  defp process_item_delete(orders, table_order, menu, deleted_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    username = if deleted_items["user"], do: deleted_items["user"]["username"], else: nil

    items_by_dept = get_items_by_department(orders, deleted_items)

    # Return payload grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, items}, acc ->
      response_data = %{
        "tables" => [
          %{
            "name" => table_data_key,
            "table_id" => table_order["id"],
            "deleted_items" => [
              %{
                "username" => username,
                "items" => items
              }
            ]
          }
        ]
      }
      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  defp process_item_edit(table_order, menu, order_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    user_order_action_status = hd(order_items)["user_order_action_status"]
    user = get_in(user_order_action_status, ["current", "user"])
    username = if user, do: user["username"], else: nil
    time = user_order_action_status["current"]["timestamp"]

    items_by_dept = group_items_by_department(order_items)

    # Return payload grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, items}, acc ->
      {pending_items, called_items} = categorize_edited_items(items)

      response_data = if pending_items != [] do
        build_pending_response(table_data_key, table_order, username, time, pending_items)
      else
        build_called_response(table_data_key, table_order, username, time, called_items)
      end

      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  defp process_item_sent_back(orders, table_order, menu, sent_back_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)

    items_by_dept = get_items_by_department(orders, sent_back_items)
    user_order_action_status = if items_by_dept != %{}, do: hd(hd(Map.values(items_by_dept)))["user_order_action_status"], else: nil
    user = if user_order_action_status, do: get_in(user_order_action_status, ["current", "user"]), else: nil
    username = if user, do: user["username"], else: nil
    time = if user_order_action_status, do: user_order_action_status["current"]["timestamp"], else: nil

    # Return payload grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, items}, acc ->
      response_data = %{
        "tables" => [
          %{
            "name" => table_data_key,
            "table_id" => table_order["id"],
            "pending_items" => [
              %{
                "username" => username,
                "time" => time,
                "items" => items
              }
            ]
          }
        ]
      }
      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  defp process_new_order(order, restaurant_id) do
    table_data_key = build_table_key(order["table_order"], order["menu"])

    enhanced_order = enhance_order_data(order)
    items_by_dept = group_items_by_department(enhanced_order["items"])

    # Return payload grouped by department ID
    Enum.reduce(items_by_dept, %{}, fn {dept_id, items}, acc ->
      response_data = %{
        "tables" => [
          %{
            "name" => table_data_key,
            "table_id" => order["table_order"]["id"],
            "order_datetime" => order["timestamp"],
            "pending_items" => [%{"items" => items}]
          }
        ]
      }
      Map.put(acc, dept_id, %{restaurant_id: restaurant_id, payload: response_data})
    end)
  end

  # Helper functions
  defp build_table_key(table_order, menu) do
    "#{table_order["name"]} #{menu["title"]}"
  end

  defp get_item_department_id(item) do
    get_in(item, ["product", "category", "department", "id"])
  end

  defp group_items_by_department(items) do
    Enum.group_by(items, &get_item_department_id/1)
  end

  defp build_action_response("Called", table_key, table_order, username, time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "called_items" => [
            %{
              "username" => username,
              "time" => time,
              "items" => items
            }
          ]
        }
      ]
    }
  end

  defp build_action_response("Delivered", table_key, table_order, username, time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "delivered_items" => [
            %{
              "username" => username,
              "time" => time,
              "items" => items
            }
          ]
        }
      ]
    }
  end

  defp build_action_response("Ready", table_key, table_order, username, time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "ready_items" => [
            %{
              "username" => username,
              "time" => time,
              "items" => items
            }
          ]
        }
      ]
    }
  end

  defp build_action_response("Paid", table_key, table_order, _username, _time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "billed_items" => [%{"items" => items}]
        }
      ]
    }
  end

  defp categorize_edited_items(items) do
    Enum.reduce(items, {[], []}, fn item, {pending, called} ->
      status = get_in(item, ["user_order_action_status", "current", "status"])
      case status do
        "Pending" -> {[item | pending], called}
        "Called" -> {pending, [item | called]}
        _ -> {pending, called}
      end
    end)
  end

  defp build_pending_response(table_key, table_order, username, time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "pending_items" => [
            %{
              "username" => username,
              "time" => time,
              "items" => items
            }
          ]
        }
      ]
    }
  end

  defp build_called_response(table_key, table_order, username, time, items) do
    %{
      "tables" => [
        %{
          "name" => table_key,
          "table_id" => table_order["id"],
          "called_items" => [
            %{
              "username" => username,
              "time" => time,
              "items" => items
            }
          ]
        }
      ]
    }
  end

  defp get_items_by_department(orders, items) do
    Enum.reduce(items["order_items"], %{}, fn item, acc ->
      order = Enum.find(orders, &(&1["_id"] == item["order_id"]))
      if order do
        Enum.reduce(item["items"], acc, fn item_id, inner_acc ->
          order_item = Enum.find(order["items"], &(&1["_id"] == item_id))
          if order_item do
            dept_id = get_item_department_id(order_item)
            Map.update(inner_acc, dept_id, [order_item], &[order_item | &1])
          else
            inner_acc
          end
        end)
      else
        acc
      end
    end)
  end

  # Assume these functions are implemented in other modules
  defp initial_state(), do: {%{}, %{}, %{}, %{}, %{}, %{pending: 0, called: 0, delivered: 0, deleted: 0}, MapSet.new()}

  defp build_final_result(table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys) do
    # Filter table_data to only include tables with department items (from Python: key in table_data_key_with_dept_items)
    filtered_table_data =
      table_data
      |> Enum.filter(fn {key, _} -> MapSet.member?(table_keys, key) end)
      |> Enum.map(fn {key, value} ->
        # Add the categorized item lists to each table (from Python: for key, value in table_data.items())
        value
        |> Map.put("pending_items", [%{"items" => Map.get(pending_items, key, [])}])
        |> Map.put("called_items", Map.get(called_items, key, %{}) |> Map.values())
        |> Map.put("ready_items", Map.get(ready_items, key, %{}) |> Map.values())
        |> Map.put("delivered_items", Map.get(delivered_items, key, %{}) |> Map.values())
      end)

    # Build the final result structure (from Python: data['tables'] = list(table_data.values()))
    %{
      "tables" => filtered_table_data,
      "delivered_items" => counts.delivered,
      "called_items" => counts.called,
      "pending_items" => counts.pending,
      "deleted_items" => counts.deleted
    }
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
          "name" => table_data_key,
          "table_id" => order["table_order"]["id"],
          "order_datetime" => order["timestamp"],
          "no_of_guests" => get_guests(order["restaurant"]["id"], order["table_order"]["id"])
        })
      else
        table_data
      end

    # Update order datetime if this order is older
    table_data =
      case {DateTime.from_iso8601(order["timestamp"]), DateTime.from_iso8601(table_data[table_data_key]["order_datetime"])} do
        {{:ok, order_dt, _}, {:ok, table_dt, _}} ->
          if DateTime.compare(order_dt, table_dt) == :lt do
            put_in(table_data, [table_data_key, "order_datetime"], order["timestamp"])
          else
            table_data
          end
        _ ->
          # Handle parsing errors - keep the existing table_data
          table_data
      end

    # Process items and track if any belong to the target department
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

  defp enhance_order_data(order) do
    order_type = order["order_type"]
    is_delivery = order_type == "MenuDelivery"
    is_takeaway = order_type == "MenuTakeAway"

    enhanced_items = Enum.map(order["items"], fn item ->
      item
      |> Map.put("order_id", order["_id"])
      |> Map.put("order_counter", order["order_counter"])
      |> Map.put("order_type", order_type)
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
    end)

    Map.put(order, "items", enhanced_items)
  end

  defp process_item(item, order_id, order_counter, order_type, estimated_preparation_time,
                  delivery_status, assigned_driver_id, estimated_delivery_time, delivery_details,
                  department_id, table_data_key, {has_items, pend, call, ready, deliv, cnt}) do
    # Enhance item with order information (from Python item enhancement)
    enhanced_item = item
      |> Map.put("order_id", order_id)
      |> Map.put("order_counter", order_counter)
      |> Map.put("order_type", order_type)
      |> Map.put("estimated_preparation_time", estimated_preparation_time)
      |> then(fn item ->
        if delivery_status do
          item
          |> Map.put("delivery_status", delivery_status)
          |> then(fn item ->
            if assigned_driver_id do
              item
              |> Map.put("assigned_driver_id", assigned_driver_id)
              |> Map.put("estimated_delivery_time", estimated_delivery_time)
              |> Map.put("delivery", delivery_details)
            else
              item
            end
          end)
        else
          item
        end
      end)

    dept = get_in(item, ["product", "category", "department"])
    user_order_action_status = item["user_order_action_status"]
    current_status = user_order_action_status["current"]["status"]

    if dept && dept["id"] == department_id do
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
    # Get or initialize the table entry
    table_data = Map.get(items_map, table_key, %{})

    # Update the user entry within the table
    updated_table_data = Map.update(table_data, username, %{"username" => username, "items" => [item]}, fn user_data ->
      update_in(user_data, ["items"], &(&1 ++ [item]))
    end)

    # Put the updated table data back into the main map
    Map.put(items_map, table_key, updated_table_data)
  end

  defp update_count(counts, key, increment) do
    Map.update(counts, key, increment, &(&1 + increment))
  end

  defp get_guests(restaurant_id, table_id) do
    case DoyoWs.TableReservationService.get_by_table(restaurant_id, table_id) do
      [] -> 0
      [hd | _tl] -> hd["guests"]
    end
  end
end
