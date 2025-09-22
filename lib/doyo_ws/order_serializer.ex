defmodule OrderSerializer do
  alias OrderSerializer.Aggregator
  alias OrderSerializer.Specifications

  @spec serialize_single_table(list(), integer()) :: map()
  def serialize_single_table(orders, table_id) do
    filtered_orders = Aggregator.filter_orders(
      orders,
      Specifications.active_orders_for_table(table_id)
    )

    %{
      table: filtered_orders,
      no_of_guests: get_no_of_guests(filtered_orders)
    }
  end

  @spec serialize_all_tables(list()) :: list()
  def serialize_all_tables(orders) do
    active_orders = Aggregator.filter_orders(orders, Specifications.active_orders())

    active_orders
    |> Aggregator.group_orders_by_table()
    |> Enum.map(fn {_table_id, table_orders} ->
      Aggregator.calculate_table_summary(table_orders)
    end)
  end

  @spec serialize_department_detail(list(), String.t() | nil) :: map()
  def serialize_department_detail(orders, department_name \\ nil) do
    active_orders = Aggregator.filter_orders(orders, Specifications.active_orders())
    department_data = Aggregator.group_items_by_department(active_orders)

    if department_name && Map.has_key?(department_data, department_name) do
      data = department_data[department_name]
      totals = Aggregator.calculate_department_totals(data)

      %{
        tables: data,
        delivered_items: totals.delivered_items,
        called_items: totals.called_items,
        pending_items: totals.pending_items,
        deleted_items: totals.deleted_items
      }
    else
      Enum.into(department_data, %{}, fn {dept_name, data} ->
        totals = Aggregator.calculate_department_totals(data)
        {dept_name, %{tables: data, totals: totals}}
      end)
    end
  end

  defp get_no_of_guests([]), do: 0
  defp get_no_of_guests([first_order | _]), do: first_order.no_of_guests
end
