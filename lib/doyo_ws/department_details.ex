defmodule DoyoWs.DepartmentDetails do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  # Public API for different update scenarios
  def get_full_department_details(restaurant_id, department_id) do
    case @redis_client.hvals("orders_#{restaurant_id}") do
      {:ok, order_list} ->
        process_all_orders(order_list, department_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_guests_update(restaurant_id, table_order, menu, table_id) do
    case fetch_table_orders(restaurant_id, table_id) do
      {:ok, orders} ->
        process_guests_update(orders, table_order, menu, restaurant_id, table_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_item_action(restaurant_id, table_order, menu, order_items, action) do
    process_item_action(table_order, menu, order_items, action, restaurant_id)
  end

  def handle_item_delete(restaurant_id, table_order, menu, deleted_items) do
    case fetch_orders_by_ids(restaurant_id, Enum.map(deleted_items, & &1["order_id"])) do
      {:ok, orders} ->
        process_item_delete(orders, table_order, menu, deleted_items, restaurant_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_item_edit(restaurant_id, table_order, menu, order_items) do
    process_item_edit(table_order, menu, order_items, restaurant_id)
  end

  def handle_item_sent_back(restaurant_id, table_order, menu, sent_back_items) do
    case fetch_orders_by_ids(restaurant_id, Enum.map(sent_back_items, & &1["order_id"])) do
      {:ok, orders} ->
        process_item_sent_back(orders, table_order, menu, sent_back_items, restaurant_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_new_order(restaurant_id, order) do
    process_new_order(order, restaurant_id)
  end

  # Private implementation
  defp process_all_orders(order_list, department_id) do
    {table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys} =
      Enum.reduce(order_list, initial_state(), fn order_str, acc ->
        case Jason.decode(order_str) do
          {:ok, order} -> process_order(order, department_id, acc)
          {:error, reason} -> log_error("Failed to decode order", reason, acc)
        end
      end)

    result = build_final_result(table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys)
    {:ok, result}
  end

  defp process_guests_update(orders, table_order, menu, restaurant_id, table_id) do
    table_data_key = build_table_key(table_order, menu)

    items_by_dept =
      orders
      |> Enum.flat_map(& &1["items"])
      |> Enum.filter(fn item -> not item["completed"] end)
      |> Enum.group_by(fn item ->
        get_in(item, ["product", "category", "department", "id"])
      end)

    Enum.map(items_by_dept, fn {dept_id, items} ->
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
      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  defp process_item_action(table_order, menu, order_items, action, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    user_order_action_status = hd(order_items)["user_order_action_status"]
    user = get_in(user_order_action_status, ["current", "user"])
    username = if user, do: user["username"], else: nil
    time = user_order_action_status["current"]["timestamp"]

    items_by_dept = group_items_by_department(order_items)

    Enum.each(items_by_dept, fn {dept_id, items} ->
      response_data = build_action_response(action, table_data_key, table_order, username, time, items)
      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  defp process_item_delete(orders, table_order, menu, deleted_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    username = if deleted_items["user"], do: deleted_items["user"]["username"], else: nil

    items_by_dept = get_deleted_items_by_department(orders, deleted_items)

    Enum.each(items_by_dept, fn {dept_id, items} ->
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
      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  defp process_item_edit(table_order, menu, order_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)
    user_order_action_status = hd(order_items)["user_order_action_status"]
    user = get_in(user_order_action_status, ["current", "user"])
    username = if user, do: user["username"], else: nil
    time = user_order_action_status["current"]["timestamp"]

    items_by_dept = group_items_by_department(order_items)

    Enum.each(items_by_dept, fn {dept_id, items} ->
      {pending_items, called_items} = categorize_edited_items(items)

      response_data = if pending_items != [] do
        build_pending_response(table_data_key, table_order, username, time, pending_items)
      else
        build_called_response(table_data_key, table_order, username, time, called_items)
      end

      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  defp process_item_sent_back(orders, table_order, menu, sent_back_items, restaurant_id) do
    table_data_key = build_table_key(table_order, menu)

    items_by_dept = get_sent_back_items_by_department(orders, sent_back_items)
    user_order_action_status = if items_by_dept != %{}, do: hd(hd(Map.values(items_by_dept)))["user_order_action_status"], else: nil
    user = if user_order_action_status, do: get_in(user_order_action_status, ["current", "user"]), else: nil
    username = if user, do: user["username"], else: nil
    time = if user_order_action_status, do: user_order_action_status["current"]["timestamp"], else: nil

    Enum.each(items_by_dept, fn {dept_id, items} ->
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
      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  defp process_new_order(order, restaurant_id) do
    table_data_key = build_table_key(order["table_order"], order["menu"])

    enhanced_order = enhance_order_data(order)
    items_by_dept = group_items_by_department(enhanced_order["items"])

    Enum.each(items_by_dept, fn {dept_id, items} ->
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
      send_websocket_message(response_data, restaurant_id, dept_id)
    end)

    :ok
  end

  # Helper functions
  defp build_table_key(table_order, menu) do
    "#{table_order["name"]} #{menu["title"]}"
  end

  defp group_items_by_department(items) do
    Enum.group_by(items, fn item ->
      get_in(item, ["product", "category", "department", "id"])
    end)
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

  defp get_deleted_items_by_department(orders, deleted_items) do
    Enum.reduce(deleted_items["order_items"], %{}, fn item, acc ->
      order = Enum.find(orders, &(&1["_id"] == item["order_id"]))
      if order do
        Enum.reduce(item["items"], acc, fn item_id, inner_acc ->
          order_item = Enum.find(order["items"], &(&1["_id"] == item_id))
          if order_item do
            dept_id = get_in(order_item, ["product", "category", "department", "id"])
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

  defp get_sent_back_items_by_department(orders, sent_back_items) do
    Enum.reduce(sent_back_items["order_items"], %{}, fn item, acc ->
      order = Enum.find(orders, &(&1["_id"] == item["order_id"]))
      if order do
        Enum.reduce(item["items"], acc, fn item_id, inner_acc ->
          order_item = Enum.find(order["items"], &(&1["_id"] == item_id))
          if order_item do
            dept_id = get_in(order_item, ["product", "category", "department", "id"])
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

  defp send_websocket_message(response_data, restaurant_id, department_id) do
    # Implementation depends on your websocket setup
    # Example: Phoenix.PubSub.broadcast(...)
    :ok
  end

  # Assume these functions are implemented in other modules
  defp fetch_table_orders(_restaurant_id, _table_id), do: {:ok, []}
  defp fetch_orders_by_ids(_restaurant_id, _order_ids), do: {:ok, []}
  defp initial_state(), do: {%{}, %{}, %{}, %{}, %{}, %{pending: 0, called: 0, delivered: 0, deleted: 0}, MapSet.new()}
  defp log_error(_message, _reason, acc), do: acc
  defp build_final_result(table_data, pending_items, called_items, ready_items, delivered_items, counts, table_keys) do
    # Implementation from previous code
    %{}
  end
  defp process_order(_order, _department_id, acc), do: acc
end
