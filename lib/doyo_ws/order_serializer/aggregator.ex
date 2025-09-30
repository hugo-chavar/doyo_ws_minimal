defmodule OrderSerializer.Aggregator do
  alias OrderSerializer.Specifications
  alias OrderSerializer.Order

  def filter_orders(orders, specification) do
    Enum.filter(orders, fn order ->
      Specifications.is_satisfied_by(specification, order)
    end)
  end

  def group_orders_by_table(orders) do
    orders
    |> Enum.group_by(fn order ->
      order.table_order.id
    end)
  end


  def group_items_by_department(orders) do
    orders
    |> Enum.flat_map(fn order ->
      Enum.map(order.items, fn item ->
        dept_id = item.product.category.department.id
        {dept_id, order, item}
      end)
    end)
    |> Enum.group_by(fn {dept_id, _, _} -> dept_id end, fn {_, order, item} ->
      {order, item}
    end)
    |> Enum.into(%{}, fn {dept_id, order_items} ->
      # Initialize department data structure
      department_data = %{
        pending_items: [],
        called_items: [],
        ready_items: [],
        delivered_items: []
      }

      # Group by status and then by table
      grouped_by_status = Enum.group_by(order_items, fn {_order, item} ->
        item.status
      end)

      department_data = Enum.reduce(grouped_by_status, department_data, fn {status, items_with_orders}, acc ->
        # Convert status string to atom key
        status_key =
          status
          |> String.downcase()
          |> then(&:"#{&1}_items")

        if Map.has_key?(acc, status_key) do
          table_groups = items_with_orders
          |> Enum.group_by(fn {order, _item} ->
            {order.table_order.name, order.table_order.id}
          end)
          |> Enum.map(fn {{table_name, table_id}, items} ->
            {first_order, _} = hd(items)
            %{
              name: "#{table_name} #{first_order.menu.title}",
              table_id: table_id,
              order_datetime: first_order.timestamp,
              no_of_guests: first_order.no_of_guests,
              items: Enum.map(items, fn {_order, item} -> item end)
            }
          end)

          Map.put(acc, status_key, table_groups)
        else
          acc
        end
      end)

      {dept_id, department_data}
    end)
  end

  defp get_guests(restaurant_id, table_id) do
    case DoyoWs.TableReservationService.get_single_table(restaurant_id, table_id) do
      %{} -> 0
      reservation -> reservation["guests"]
    end
  end

  def calculate_table_summary(table_orders) when is_list(table_orders) and table_orders != [] do
    latest_order = Enum.max_by(table_orders, & &1.timestamp)
    has_new_orders = contains_new_orders(table_orders)
    guests = get_guests(latest_order.restaurant["id"], latest_order.table_order.id)
    total_amount = table_orders
      |> Enum.map(& &1.total)
      |> Enum.sum()
      |> Float.round(2)

    total_items = table_orders
      |> Enum.map(& &1.total_items)
      |> Enum.sum()

    item_classification_summary = summarize_item_classifications(table_orders)

    %{
      table_order: latest_order.table_order,
      menu: latest_order.menu,
      order_type: latest_order.order_type,
      order_datetime: latest_order.timestamp,
      latest_order_datetime: latest_order.timestamp,
      last_action_datetime: get_last_action_datetime(table_orders),
      total_amount: total_amount,
      total_items: total_items,
      pending_items: item_classification_summary["Pending"].count,
      called_items: item_classification_summary["Called"].count,
      called_items_start_time: item_classification_summary["Called"].earliest_timestamp,
      ready_items: item_classification_summary["Ready"].count,
      ready_items_start_time: item_classification_summary["Ready"].earliest_timestamp,
      delivered_items: item_classification_summary["Delivered"].count,
      delivered_items_start_time: item_classification_summary["Delivered"].earliest_timestamp,
      paid_items: item_classification_summary["Paid"].count,
      paid_items_start_time: item_classification_summary["Paid"].earliest_timestamp,
      no_of_guests: guests,
      new_order: has_new_orders,
      billed: Enum.all?(table_orders, & &1.billed)
    }
  end

  def calculate_table_summary([]), do: %{}

  defp get_last_action_datetime(orders) do
    orders
    |> Enum.flat_map(fn order ->
      [order.last_action_datetime]
    end)
    |> Enum.max
  end


  def calculate_department_totals(department_data) do
    %{
      pending_items: count_items_in_status_group(department_data["pending_items"]),
      called_items: count_items_in_status_group(department_data["called_items"]),
      ready_items: count_items_in_status_group(department_data["ready_items"]),
      delivered_items: count_items_in_status_group(department_data["delivered_items"]),
      deleted_items: 0 # TODO: Would need separate calculation
    }
  end

  defp count_items_in_status_group(status_group) when is_list(status_group) do
    Enum.reduce(status_group, 0, fn table_group, acc ->
      acc + length(table_group[:items] || [])
    end)
  end
  defp count_items_in_status_group(_), do: 0

  defp contains_new_orders(orders) when is_list(orders) do

    {:ok, current_datetime} = DateTime.now("Etc/UTC")
    past_datetime = DateTime.add(current_datetime, -10, :minute)


    orders
    |> Enum.filter(fn order ->
        DateTime.compare(order.timestamp, past_datetime) == :gt and Enum.all?(order.items, fn item ->
          item.is_new
        end)
      end)
    |> Enum.any?()
  end

  defp summarize_item_classifications(orders) when is_list(orders) do
    initial_state = %{
      "Called" => %{count: 0, earliest_timestamp: nil, items: []},
      "Delivered" => %{count: 0, earliest_timestamp: nil, items: []},
      "Pending" => %{count: 0, earliest_timestamp: nil, items: []},
      "Paid" => %{count: 0, earliest_timestamp: nil, items: []},
      "Ready" => %{count: 0, earliest_timestamp: nil, items: []}
    }

    Enum.reduce(orders, initial_state, fn order, acc ->
      case order do
        %Order{item_classification: classification} when is_map(classification) ->
          merge_classifications(acc, classification)
        _ ->
          acc # Skip if no classification or invalid format
      end
    end)
  end

  defp merge_classifications(acc, classification) do
    Enum.reduce(Map.keys(acc), acc, fn status, acc ->
      acc_status_data = acc[status]
      classification_status_data = classification[status]

      case classification_status_data do
        %{count: count, earliest_timestamp: timestamp, items: items} ->
          merged_count = acc_status_data.count + count

          merged_items = acc_status_data.items ++ items

          merged_earliest_timestamp =
            case {acc_status_data.earliest_timestamp, timestamp} do
              {nil, nil} -> nil
              {nil, t} -> t
              {acc_t, nil} -> acc_t
              {acc_t, new_t} ->
                if DateTime.compare(new_t, acc_t) == :lt, do: new_t, else: acc_t
            end

          Map.put(acc, status, %{
            count: merged_count,
            earliest_timestamp: merged_earliest_timestamp,
            items: merged_items
          })

        _ ->
          acc # Status not present in classification, keep accumulator
      end
    end)
  end

end
