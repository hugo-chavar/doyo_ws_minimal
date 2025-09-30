defmodule OrderSerializer.DataMapper do
  alias OrderSerializer.{Order, OrderItem, Product, Category, Department, Table, Menu}
  require Logger

  def map_order(order_data) when is_map(order_data) do
    incomplete_items = order_data["items"] |> Enum.reject(&(&1["completed"] || &1["deleted"]))

    %Order{
      _id: order_data["_id"],
      table_order: map_table(order_data["table_order"]),
      menu: map_menu(order_data["menu"]),
      order_type: order_data["order_type"],
      timestamp: parse_datetime(order_data["timestamp"]),
      items: Enum.map(order_data["items"] || [], &map_order_item/1),
      total: float_round(order_data["total"]),
      total_items: length(incomplete_items),
      no_of_guests: order_data["no_of_guests"],
      completed: order_data["completed"] || false,
      billed: Enum.empty?(incomplete_items),
      unbilled_amount: incomplete_items
        |> Enum.map(& &1["ordered_price"])
        |> Enum.sum(),
      discount: float_round(order_data["discount"]),
      subtotal: float_round(order_data["subtotal"]),
      vat: float_round(order_data["vat"]),
      service_fee: float_round(order_data["service_fee"]),
      flat_person_fee: float_round(order_data["flat_person_fee"]),
      home_delivery_fee: float_round(order_data["home_delivery_fee"]),
      restaurant: order_data["restaurant"],
      order_counter: order_data["order_counter"],
      mode_of_payment: order_data["mode_of_payment"],
      estimated_preparation_time: order_data["estimated_preparation_time"],
      estimated_delivery_time: order_data["estimated_delivery_time"],
      last_action_datetime: get_last_action_datetime(order_data["items"]),
      item_classification: classify_items(order_data["items"]),
      active: order_data["active"],
      t: order_data["t"] || "Other"
    }
  end

  defp map_order_item(item_data) do
    %OrderItem{
      _id: item_data["_id"],
      product: map_product(item_data["product"]),
      status: get_item_status(item_data),
      user_order_action_status: item_data["user_order_action_status"],
      actual_price: float_round(item_data["actual_price"]),
      ordered_price: float_round(item_data["ordered_price"]),
      completed: item_data["completed"] || false,
      deleted: item_data["deleted"] || false,
      paid: item_data["paid"] || false,
      timestamp: get_item_timestamp(item_data),
      is_new: item_is_new(item_data),
      note: item_data["note"] || "",
      service_fee: float_round(item_data["service_fee"]),
      service_fee_vat: float_round(item_data["service_fee_vat"]),
      product_vat: float_round(item_data["product_vat"]),
      total_vat: float_round(item_data["total_vat"]),
      total_price: float_round(item_data["total_price"]),
      price_paid: float_round(item_data["price_paid"]),
      price_remaining: (item_data["price_remaining"]),
      promo_discount: float_round(item_data["promo_discount"]),
      order_discount: float_round(item_data["order_discount"]),
      total_discount: float_round(item_data["total_discount"]),
      tag: item_data["tag"],
      round: item_data["round"],
      order_id: item_data["order_id"],
      order_type: item_data["order_type"],
      order_counter: item_data["order_counter"],
      estimated_preparation_time: item_data["estimated_preparation_time"],
      estimated_delivery_time: item_data["estimated_delivery_time"],
      delivery_status: item_data["delivery_status"]
    }
  end

  defp map_product(product_data) when is_map(product_data) do
    %Product{
      id: product_data["id"],
      title: product_data["title"],
      category: map_category(product_data["category"]),
      price: float_round(product_data["price"]),
      vat: float_round(product_data["vat"]),
      images: product_data["images"] || [],
      format: product_data["format"],
      extras: product_data["extras"],
    }
  end

  defp map_category(category_data) when is_map(category_data) do
    %Category{
      id: category_data["id"],
      name: category_data["name"],
      department: map_department(category_data["department"])
    }
  end

  defp map_department(department_data) when is_map(department_data) do
    %Department{
      id: department_data["id"],
      name: department_data["name"]
    }
  end

  defp map_table(table_data) when is_map(table_data) do
    %Table{
      id: table_data["id"],
      name: table_data["name"]
    }
  end

  defp map_menu(menu_data) when is_map(menu_data) do
    %Menu{
      id: menu_data["id"],
      title: menu_data["title"],
      service_fee: float_round(menu_data["service_fee"]),
      service_fee_vat: float_round(menu_data["service_fee_vat"]),
      flat_person_fee: float_round(menu_data["flat_person_fee"]),
      flat_person_fee_vat: float_round(menu_data["flat_person_fee_vat"]),
      home_delivery_fee: float_round(menu_data["home_delivery_fee"]),
      home_delivery_fee_vat: float_round(menu_data["home_delivery_fee_vat"]),
      estimated_preparation_time: menu_data["estimated_preparation_time"],
      estimated_delivery_time: menu_data["estimated_delivery_time"],
    }
  end

  defp get_item_status(item_data) do
    case item_data do
      %{"user_order_action_status" => %{"current" => %{"status" => status}}} -> status
      _ -> {:error, "Status not found"}
    end
  end

  defp get_item_timestamp(item_data) do
    # Logger.info("get_item_timestamp. #{inspect(item_data)}")
    case item_data do
      %{"user_order_action_status" => %{"current" => %{"timestamp" => ts}}} ->
        parse_datetime(ts)
      _ -> {:error, "Missing item timestamp"}
    end
  end

  defp item_is_new(item_data) do
    cond do
      item_data["user_order_action_status"]["history"] != nil ->
        false
      get_item_status(item_data) != "Pending" ->
        false
      item_data["completed"] || item_data["deleted"] ->
        false
      true ->
        item_timestamp = get_item_timestamp(item_data)
        {:ok, current_datetime} = DateTime.now("Etc/UTC")
        past_datetime = DateTime.add(current_datetime, -30, :minute)
        DateTime.compare(item_timestamp, past_datetime) == :gt
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _offset} ->
        # Logger.info("DateTime.from_iso8601. #{datetime_str}")
        dt
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive_dt} ->
            {:ok, dt} = DateTime.from_naive(naive_dt, "Etc/UTC")
            # Logger.info("DateTime.from_naive. #{datetime_str}")
            dt
          error -> error
        end
      error -> error
    end
  end

  defp get_last_action_datetime(items) do
    items
    |> Enum.flat_map(fn item ->
      user_order_action_status = item["user_order_action_status"]

      timestamps = []
      |> check_current_status(user_order_action_status, "Delivered")
      |> check_history_status(user_order_action_status, "Delivered")
      |> check_current_status(user_order_action_status, "Called")
      |> check_history_status(user_order_action_status, "Called")

      timestamps
    end)
    |> get_max_timestamp()
  end

  defp check_current_status(timestamps, user_order_action_status, target_status) do
    case user_order_action_status do
      %{"current" => %{"status" => ^target_status, "timestamp" => timestamp}} ->
        [parse_datetime(timestamp) | timestamps]
      _ ->
        timestamps
    end
  end

  defp check_history_status(timestamps, user_order_action_status, target_status) do
    case user_order_action_status do
      %{"history" => history} when is_list(history) ->
        case Enum.find(history, &(&1["status"] == target_status)) do
          %{"timestamp" => timestamp} -> [parse_datetime(timestamp) | timestamps]
          nil -> timestamps
        end
      _ ->
        timestamps
    end
  end

  defp get_max_timestamp([]), do: nil
  defp get_max_timestamp(timestamps), do: Enum.max(timestamps)

  defp classify_items(items) do
    initial_state = %{
      "Called" => %{count: 0, earliest_timestamp: nil, items: []},
      "Delivered" => %{count: 0, earliest_timestamp: nil, items: []},
      "Pending" => %{count: 0, earliest_timestamp: nil, items: []},
      "Paid" => %{count: 0, earliest_timestamp: nil, items: []},
      "Ready" => %{count: 0, earliest_timestamp: nil, items: []}
    }

    Enum.reduce(items, initial_state, fn item, acc ->
      process_item(item, acc)
    end)
  end

  defp process_item(item, acc) do
    current_status = item["user_order_action_status"]["current"]["status"]

    # Update current status count and items
    acc = update_current_status(acc, current_status, item)

    # Update earliest timestamps from history (including current)
    update_earliest_timestamps_from_history(acc, item)
  end

  defp update_current_status(acc, status, item) do
    case acc[status] do
      %{count: count, items: items} = status_data ->
        Map.put(acc, status, %{
          status_data |
          count: count + 1,
          items: [item | items]
        })
      nil -> acc # Status not in our classification map
    end
  end

  defp update_earliest_timestamps_from_history(acc, item) do
    status_history =
      [item["user_order_action_status"]["current"]] ++
      (item["user_order_action_status"]["history"] || [])

    Enum.reduce(status_history, acc, fn status_entry, acc ->
      status = status_entry["status"]
      timestamp = status_entry["timestamp"]

      if status && timestamp && acc[status] do
        new_dt = parse_datetime(timestamp)
        update_earliest_timestamp(acc, status, new_dt)
      else
        acc
      end
    end)
  end

  defp update_earliest_timestamp(acc, status, new_dt) do
    %{earliest_timestamp: current_timestamp} = acc[status]

    new_earliest =
      case current_timestamp do
        nil -> new_dt
        current_dt ->
          # Compare timestamps to find the earliest

          if DateTime.compare(new_dt, current_dt) == :lt do
            new_dt
          else
            current_dt
          end
      end

    Map.put(acc, status, %{acc[status] | earliest_timestamp: new_earliest})
  end

  defp float_round(value) do
    (value|| 0.0) |> Float.round(2)
  end

end
