defmodule OrderSerializer.Department do
  defstruct [:id, :name]
end

defmodule OrderSerializer.Table do
  defstruct [:id, :name]
end

defmodule OrderSerializer.Menu do
  defstruct [
    :id, :title, :service_fee, :service_fee_vat,
    :flat_person_fee, :flat_person_fee_vat,
    :home_delivery_fee, :home_delivery_fee_vat
  ]
end

defmodule OrderSerializer.Category do
  defstruct [:id, :name, :department]
end

defmodule OrderSerializer.Product do
  defstruct [
    :id, :title, :category, :price, :vat, :images,
    :format, :extras, :promotion, :cogs
  ]
end

defmodule OrderSerializer.OrderItem do
  defstruct [
    :_id, :product, :status, :user_order_action_status, :actual_price,
    :ordered_price, :completed, :deleted, :paid, :timestamp, :note,
    :service_fee, :product_vat, :total_price, :price_paid, :tag, :order_id,
    :order_type, :estimated_preparation_time, :delivery_status
  ]
end

defmodule OrderSerializer.Order do
  defstruct [
    :_id, :table_order, :menu, :order_type, :order_datetime, :items,
    :total_amount, :total_items, :no_of_guests, :completed, :subtotal,
    :vat, :service_fee, :flat_person_fee, :restaurant, :order_counter,
    :latest_order_datetime, :last_action_datetime, :currency, :billed,
    :pending_items, :called_items, :ready_items, :delivered_items,
    :sent_back_items, :active, :t
  ]
end
