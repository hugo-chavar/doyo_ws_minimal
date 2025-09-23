defmodule OrderSerializer.Department do
  @derive {Jason.Encoder, only: [:id, :name]}
  defstruct [:id, :name]
end

defmodule OrderSerializer.Table do
  @derive {Jason.Encoder, only: [:id, :name]}
  defstruct [:id, :name]
end

defmodule OrderSerializer.Menu do
  @derive {Jason.Encoder, only: [
    :id, :title, :service_fee, :service_fee_vat, :flat_person_fee,
    :flat_person_fee_vat, :home_delivery_fee, :home_delivery_fee_vat
  ]}
  defstruct [
    :id, :title, :service_fee, :service_fee_vat, :flat_person_fee,
    :flat_person_fee_vat, :home_delivery_fee, :home_delivery_fee_vat
  ]
end

defmodule OrderSerializer.Category do
  @derive {Jason.Encoder, only: [:id, :name, :department]}
  defstruct [:id, :name, :department]
end

defmodule OrderSerializer.Restaurant do
  @derive {Jason.Encoder, only: [:id, :name, :currency]}
  defstruct [:id, :name, :currency]
end

defmodule OrderSerializer.Product do
  @derive {Jason.Encoder, only: [
    :id, :title, :category, :price, :vat, :images, :format, :extras
  ]}
  defstruct [
    :id, :title, :category, :price, :vat, :images, :format, :extras,
    :promotion
  ]
end

defmodule OrderSerializer.OrderItem do
  @derive {Jason.Encoder, only: [
    :_id, :product, :status, :user_order_action_status, :actual_price,
    :ordered_price, :completed, :deleted, :paid, :timestamp, :note,
    :service_fee, :product_vat, :total_price, :price_paid, :tag,
    :delivery_status
  ]}
  defstruct [
    :_id, :product, :status, :user_order_action_status, :actual_price,
    :ordered_price, :completed, :deleted, :paid, :timestamp, :note,
    :service_fee, :product_vat, :total_price, :price_paid, :tag, :order_id,
    :order_type, :delivery_status, :estimated_preparation_time, :estimated_delivery_time
  ]
end

defmodule OrderSerializer.Order do
  @derive {Jason.Encoder, only: [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee,

  ]}
  defstruct [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed,
    :total_items,  :latest_order_datetime, :last_action_datetime, :active, :t,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee,
    :pending_items, :called_items, :ready_items, :delivered_items, :sent_back_items
  ]
end
