defmodule OrderSerializer.DataMapper do
  alias OrderSerializer.{Order, OrderItem, Product, Category, Department, Table, Menu}

  def map_order(order_data) when is_map(order_data) do
    %Order{
      _id: order_data["_id"],
      table_order: map_table(order_data["table_order"]),
      menu: map_menu(order_data["menu"]),
      order_type: order_data["order_type"],
      timestamp: parse_datetime(order_data["timestamp"]),
      items: Enum.map(order_data["items"] || [], &map_order_item/1),
      total: order_data["total"],
      total_items: get_item_count(order_data["items"]),
      no_of_guests: order_data["no_of_guests"],
      completed: order_data["completed"] || false,
      billed: Enum.all?(order_data["items"], fn item ->
        item["completed"] or item["deleted"]
      end),
      subtotal: order_data["subtotal"],
      vat: order_data["vat"],
      service_fee: order_data["service_fee"],
      flat_person_fee: order_data["flat_person_fee"],
      home_delivery_fee: order_data["home_delivery_fee"],
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
      t: order_data["t"]
    }
  end

  defp map_order_item(item_data) do
    %OrderItem{
      _id: item_data["_id"],
      product: map_product(item_data["product"]),
      status: get_item_status(item_data),
      user_order_action_status: item_data["user_order_action_status"],
      actual_price: item_data["actual_price"],
      ordered_price: item_data["ordered_price"],
      completed: item_data["completed"] || false,
      deleted: item_data["deleted"] || false,
      paid: item_data["paid"] || false,
      timestamp: get_item_timestamp(item_data),
      note: item_data["note"],
      service_fee: item_data["service_fee"],
      service_fee_vat: item_data["service_fee_vat"],
      product_vat: item_data["product_vat"],
      total_vat: item_data["total_vat"],
      total_price: item_data["total_price"],
      price_paid: item_data["price_paid"],
      price_remaining: item_data["price_remaining"],
      promo_discount: item_data["promo_discount"],
      order_discount: item_data["order_discount"],
      total_discount: item_data["total_discount"],
      tag: item_data["tag"],
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
      price: product_data["price"],
      vat: product_data["vat"],
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
      service_fee: menu_data["service_fee"],
      service_fee_vat: menu_data["service_fee_vat"],
      flat_person_fee: menu_data["flat_person_fee"],
      flat_person_fee_vat: menu_data["flat_person_fee_vat"],
      home_delivery_fee: menu_data["home_delivery_fee"],
      home_delivery_fee_vat: menu_data["home_delivery_fee_vat"],
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
    case item_data do
      %{"user_order_action_status" => %{"current" => %{"timestamp" => ts}}} ->
        parse_datetime(ts)
      _ -> {:error, "Missing item timestamp"}
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _offset} ->
        dt
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive_dt} ->
            {:ok, dt} = DateTime.from_naive(naive_dt, "Etc/UTC")
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
