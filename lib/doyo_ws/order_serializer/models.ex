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
    :flat_person_fee_vat, :home_delivery_fee, :home_delivery_fee_vat,
    :estimated_preparation_time, :estimated_delivery_time
  ]}
  defstruct [
    :id, :title, :service_fee, :service_fee_vat, :flat_person_fee,
    :flat_person_fee_vat, :home_delivery_fee, :home_delivery_fee_vat,
    :estimated_preparation_time, :estimated_delivery_time
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
  @derive {Jason.Encoder, except: [
    :promotion
  ]}
  defstruct [
    :id, :title, :category, :price, :vat, :images, :format, :extras,
    :promotion
  ]
end

defmodule OrderSerializer.OrderItem do
  @derive {Jason.Encoder, except: [
    :order_id, :order_type
  ]}
  defstruct [
    :_id, :order_type, :product, :status, :user_order_action_status,
    :completed, :deleted, :paid, :timestamp, :note, :tag, :order_id,
    :actual_price, :ordered_price, :total_price,
    :product_vat, :service_fee_vat, :total_vat,
    :service_fee, :price_paid, :price_remaining,
    :promo_discount, :order_discount, :total_discount,
    :delivery_status, :estimated_preparation_time, :estimated_delivery_time
  ]
end

defmodule OrderSerializer.Order do
  @derive {Jason.Encoder, only: [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed, :billed, :mode_of_payment,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee,
    :discount, :estimated_preparation_time, :estimated_delivery_time,
    :delivery
  ]}
  defstruct [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed, :billed, :mode_of_payment,
    :total_items,  :latest_order_datetime, :last_action_datetime, :active, :t,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee,
    :pending_items, :called_items, :ready_items, :delivered_items, :sent_back_items,
    :discount, :estimated_preparation_time, :estimated_delivery_time,
    :delivery
  ]
end
