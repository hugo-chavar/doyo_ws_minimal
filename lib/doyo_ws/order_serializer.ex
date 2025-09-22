defmodule OrderSerializer do
  alias OrderSerializer.{Aggregator, Serializers}

  defstruct [:orders, :aggregator]

  def new(orders) do
    %__MODULE__{
      orders: orders,
      aggregator: Aggregator
    }
  end

  def serialize(%__MODULE__{} = service, serializer) do
    serializer.serialize(serializer, service.aggregator, service.orders)
  end

  # Convenience functions
  def serialize_single_table(service, table_id) do
    serialize(service, Serializers.SingleTable.new(table_id))
  end

  def serialize_all_tables(service) do
    serialize(service, Serializers.AllTables.new())
  end

  def serialize_department_detail(service, department_name \\ nil) do
    serialize(service, Serializers.DepartmentDetail.new(department_name))
  end
end
