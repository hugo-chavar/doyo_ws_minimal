defmodule OrderSerializer.DataMapper do
  alias OrderSerializer.{Order, OrderItem, Product, Category, Department, Table, Menu}
  require Logger

  def map_order(order_data) when is_map(order_data) do
    %Order{
      _id: order_data["_id"],
      table_order: map_table(order_data["table_order"]),
      menu: map_menu(order_data["menu"]),
      order_type: order_data["order_type"],
      timestamp: parse_datetime(order_data["timestamp"]),
      items: Enum.map(order_data["items"] || [], &map_order_item/1),
      total: order_data["total"] || 0.0,
      total_items: get_item_count(order_data["items"]),
      no_of_guests: order_data["no_of_guests"],
      completed: order_data["completed"] || false,
      billed: Enum.all?(order_data["items"], fn item ->
        item["completed"] || false or item["deleted"] || false
      end),
      subtotal: order_data["subtotal"] || 0.0,
      vat: order_data["vat"] || 0.0,
      service_fee: order_data["service_fee"] || 0.0,
      flat_person_fee: order_data["flat_person_fee"] || 0.0,
      home_delivery_fee: order_data["home_delivery_fee"] || 0.0,
      restaurant: order_data["restaurant"],
      order_counter: order_data["order_counter"],
      latest_order_datetime: parse_datetime(order_data["timestamp"]),
      last_action_datetime: get_last_action_datetime(order_data["items"]),
      pending_items: [],
      called_items: [],
      ready_items: [],
      delivered_items: [],
      sent_back_items: [],
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
      actual_price: item_data["actual_price"] || 0.0 |> Float.round(2),
      ordered_price: item_data["ordered_price"] || 0.0 |> Float.round(2),
      completed: item_data["completed"] || false,
      deleted: item_data["deleted"] || false,
      paid: item_data["paid"] || false,
      timestamp: get_item_timestamp(item_data),
      is_new: item_is_new(item_data),
      note: item_data["note"] || "",
      service_fee: item_data["service_fee"] || 0.0 |> Float.round(2),
      service_fee_vat: item_data["service_fee_vat"] || 0.0 |> Float.round(2),
      product_vat: item_data["product_vat"] || 0.0 |> Float.round(2),
      total_vat: item_data["total_vat"] || 0.0 |> Float.round(2),
      total_price: item_data["total_price"] || 0.0 |> Float.round(2),
      price_paid: item_data["price_paid"] || 0.0 |> Float.round(2),
      price_remaining: item_data["price_remaining"] || 0.0 |> Float.round(2),
      promo_discount: item_data["promo_discount"] || 0.0 |> Float.round(2),
      order_discount: item_data["order_discount"] || 0.0 |> Float.round(2),
      total_discount: item_data["total_discount"] || 0.0 |> Float.round(2),
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
      price: product_data["price"] || 0.0,
      vat: product_data["vat"] || 0.0,
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
      service_fee: menu_data["service_fee"] || 0.0,
      service_fee_vat: menu_data["service_fee_vat"] || 0.0,
      flat_person_fee: menu_data["flat_person_fee"] || 0.0,
      flat_person_fee_vat: menu_data["flat_person_fee_vat"] || 0.0,
      home_delivery_fee: menu_data["home_delivery_fee"] || 0.0,
      home_delivery_fee_vat: menu_data["home_delivery_fee_vat"] || 0.0,
      estimated_preparation_time: menu_data["estimated_preparation_time"],
      estimated_delivery_time: menu_data["estimated_delivery_time"],
    }
  end

  defp get_item_status(item_data) do
    case item_data do
      %{"user_order_action_status" => %{"current" => %{"status" => status}}} -> status
      %{"status" => status} -> status
      _ -> "Pending" # default status
    end
  end

  defp get_item_timestamp(item_data) do
    Logger.info("get_item_timestamp. #{inspect(item_data)}")
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
      item_data["completed"] || false or item_data["deleted"] || false ->
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
        Logger.info("DateTime.from_iso8601. #{datetime_str}")
        dt
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive_dt} ->
            {:ok, dt} = DateTime.from_naive(naive_dt, "Etc/UTC")
            Logger.info("DateTime.from_naive. #{datetime_str}")
            dt
          error -> error
        end
      error -> error
    end
  end

  defp get_last_action_datetime(items) do
    items
    |> Enum.flat_map(fn item ->
      case item["user_order_action_status"] do
        %{"current" => %{"timestamp" => timestamp}} -> [parse_datetime(timestamp)]
        _ -> []
      end
    end)
    |> case do
      [] ->
        nil
      timestamps ->
        Enum.max(timestamps)
    end
  end

  defp get_item_count(items) do
    Enum.reduce(items, 0, fn item, acc ->
      if item["completed"], do: acc, else: acc + 1
    end)
  end

end
