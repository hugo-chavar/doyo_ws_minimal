defmodule OrderSerializer.Specifications do
  alias OrderSerializer.Order

  # Base specification behavior
  defmacro __using__(_opts) do
    quote do
      @behaviour OrderSerializer.Specification
    end
  end

  @callback is_satisfied_by(order :: Order.t()) :: boolean()

  # Active order specification
  defmodule ActiveOrder do
    @behaviour OrderSerializer.Specification

    def is_satisfied_by(%Order{completed: completed}), do: not completed
  end

  # Department specification
  defmodule Department do
    @behaviour OrderSerializer.Specification

    defstruct [:department_id]

    def new(department_id), do: %__MODULE__{department_id: department_id}

    def is_satisfied_by(%__MODULE__{department_id: dept_id}, %Order{items: items}) do
      Enum.any?(items, fn item ->
        item.product.category.department.id == dept_id
      end)
    end
  end

  # Table specification
  defmodule Table do
    @behaviour OrderSerializer.Specification

    defstruct [:table_id]

    def new(table_id), do: %__MODULE__{table_id: table_id}

    def is_satisfied_by(%__MODULE__{table_id: table_id}, %Order{table_order: %{"id" => order_table_id}}) do
      order_table_id == table_id
    end
  end

  # Item status specification
  defmodule ItemStatus do
    @behaviour OrderSerializer.Specification

    defstruct [:status]

    def new(status), do: %__MODULE__{status: status}

    def is_satisfied_by(%__MODULE__{status: status}, %Order{items: items}) do
      Enum.any?(items, fn item -> item.status == status end)
    end
  end

  # Composite AND specification
  defmodule And do
    @behaviour OrderSerializer.Specification

    defstruct [:specifications]

    def new(specifications), do: %__MODULE__{specifications: List.wrap(specifications)}

    def is_satisfied_by(%__MODULE__{specifications: specs}, order) do
      Enum.all?(specs, fn spec -> OrderSerializer.Specifications.is_satisfied_by(spec, order) end)
    end
  end

  # Helper function to apply any specification
  def is_satisfied_by(specification, order) do
    case specification do
      %module{} = spec when is_struct(spec, module) ->
        module.is_satisfied_by(spec, order)
      func when is_function(func, 1) ->
        func.(order)
      _ ->
        false
    end
  end

  # Common specification combinations
  def active_orders do
    %ActiveOrder{}
  end

  def active_orders_for_table(table_id) do
    And.new([%ActiveOrder{}, %Table{table_id: table_id}])
  end

  def active_orders_for_department(department_id) do
    And.new([%ActiveOrder{}, %Department{department_id: department_id}])
  end
end
