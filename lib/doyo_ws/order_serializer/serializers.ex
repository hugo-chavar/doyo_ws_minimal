defmodule OrderSerializer.Serializers do
  alias OrderSerializer.Aggregator
  alias OrderSerializer.Specifications

  @callback serialize(aggregator :: module(), orders :: list()) :: map() | list()

  # Single Table Serializer
  defmodule SingleTable do
    @behaviour OrderSerializer.Serializers

    defstruct [:table_id]

    def new(table_id), do: %__MODULE__{table_id: table_id}

    def serialize(%__MODULE__{table_id: table_id}, aggregator, orders) do
      filtered_orders = Aggregator.filter_orders(
        orders,
        Specifications.active_orders_for_table(table_id)
      )

      %{
        table: filtered_orders,
        no_of_guests: get_no_of_guests(filtered_orders)
      }
    end

    defp get_no_of_guests([]), do: 0
    defp get_no_of_guests([first_order | _]), do: first_order.no_of_guests
  end

  # All Tables Serializer
  defmodule AllTables do
    @behaviour OrderSerializer.Serializers

    defstruct []

    def new, do: %__MODULE__{}

    def serialize(%__MODULE__{}, aggregator, orders) do
      active_orders = Aggregator.filter_orders(orders, Specifications.active_orders())

      active_orders
      |> Aggregator.group_orders_by_table()
      |> Enum.map(fn {_table_id, table_orders} ->
        Aggregator.calculate_table_summary(table_orders)
      end)
    end
  end

  # Department Detail Serializer
  defmodule DepartmentDetail do
    @behaviour OrderSerializer.Serializers

    defstruct [:department_name]

    def new(department_name \\ nil), do: %__MODULE__{department_name: department_name}

    def serialize(%__MODULE__{department_name: dept_name}, aggregator, orders) do
      active_orders = Aggregator.filter_orders(orders, Specifications.active_orders())
      department_data = Aggregator.group_items_by_department(active_orders)

      if dept_name && Map.has_key?(department_data, dept_name) do
        data = department_data[dept_name]
        %{
          tables: data,
          delivered_items: Aggregator.calculate_department_totals(data).delivered_items,
          called_items: Aggregator.calculate_department_totals(data).called_items,
          pending_items: Aggregator.calculate_department_totals(data).pending_items,
          deleted_items: 0 # Would need calculation
        }
      else
        # Return all departments
        Enum.into(department_data, %{}, fn {dept_name, data} ->
          totals = Aggregator.calculate_department_totals(data)
          {dept_name, %{tables: data, totals: totals}}
        end)
      end
    end
  end
end
