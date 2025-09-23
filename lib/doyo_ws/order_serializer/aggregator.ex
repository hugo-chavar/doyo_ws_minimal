defmodule OrderSerializer.Aggregator do
  alias OrderSerializer.Specifications

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
        status_key = "#{String.downcase(status)}_items"

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
              order_datetime: first_order.order_datetime,
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

  def calculate_table_summary(table_orders) when is_list(table_orders) and table_orders != [] do
    latest_order = Enum.max_by(table_orders, & &1.order_datetime)

    %{
      table_order: latest_order.table_order,
      menu: latest_order.menu,
      order_type: latest_order.order_type,
      order_datetime: latest_order.order_datetime,
      latest_order_datetime: latest_order.order_datetime,
      last_action_datetime: get_last_action_datetime(table_orders),
      total_amount: Enum.reduce(table_orders, 0, &(&2 + &1.total_amount)),
      total_items: Enum.reduce(table_orders, 0, &(&2 + &1.total_items)),
      pending_items: count_items_by_status(table_orders, "Pending"),
      called_items: count_items_by_status(table_orders, "Called"),
      ready_items: count_items_by_status(table_orders, "Ready"),
      delivered_items: count_items_by_status(table_orders, "Delivered"),
      no_of_guests: latest_order.no_of_guests,
      currency: latest_order.currency,
      new_order: false, # This would need business logic
      billed: latest_order.billed || false
    }
  end

  def calculate_table_summary([]), do: %{}

  defp get_last_action_datetime(orders) do
    orders
    |> Enum.flat_map(fn order ->
      Enum.flat_map(order.items, fn item ->
        case item.user_order_action_status do
          %{"current" => %{"timestamp" => timestamp}} -> [timestamp]
          _ -> []
        end
      end)
    end)
    |> case do
      [] ->
        hd(orders).order_datetime
      timestamps ->
        Enum.max(timestamps)
    end
  end

  defp count_items_by_status(orders, status) do
    orders
    |> Enum.flat_map(& &1.items)
    |> Enum.filter(fn item ->
      item.status == status and not item.deleted
    end)
    |> length()
  end

  def calculate_department_totals(department_data) do
    %{
      pending_items: count_items_in_status_group(department_data["pending_items"]),
      called_items: count_items_in_status_group(department_data["called_items"]),
      ready_items: count_items_in_status_group(department_data["ready_items"]),
      delivered_items: count_items_in_status_group(department_data["delivered_items"]),
      deleted_items: 0 # Would need separate calculation
    }
  end

  defp count_items_in_status_group(status_group) when is_list(status_group) do
    Enum.reduce(status_group, 0, fn table_group, acc ->
      acc + length(table_group[:items] || [])
    end)
  end
  defp count_items_in_status_group(_), do: 0
end
