defmodule OrderSerializer.Department do
  @derive {JSON.Encoder, only: [:id, :name]}
  defstruct [:id, :name]
end

defmodule OrderSerializer.Table do
  @derive {JSON.Encoder, only: [:id, :name]}
  defstruct [:id, :name]
end

defmodule OrderSerializer.Menu do
  @derive {JSON.Encoder, only: [
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
  @derive {JSON.Encoder, only: [:id, :name, :department]}
  defstruct [:id, :name, :department]
end

defmodule OrderSerializer.Restaurant do
  @derive {JSON.Encoder, only: [:id, :name, :currency]}
  defstruct [:id, :name, :currency]
end

defmodule OrderSerializer.Product do
  @derive {JSON.Encoder, except: [
    :promotion
  ]}
  defstruct [
    :id, :title, :category, :price, :vat, :images, :format, :extras,
    :promotion
  ]
end

defmodule OrderSerializer.OrderItem do
  @derive {JSON.Encoder, except: [
    :is_new, :status, :timestamp
  ]}
  defstruct [
    :_id, :order_id, :order_type, :order_counter, :product,
    :status, :user_order_action_status, :round, :is_new,
    :completed, :deleted, :paid, :timestamp, :note, :tag,
    :actual_price, :ordered_price, :total_price,
    :product_vat, :service_fee_vat, :total_vat,
    :service_fee, :price_paid, :price_remaining,
    :promo_discount, :order_discount, :total_discount,
    :delivery_status, #:estimated_preparation_time, :estimated_delivery_time,
    # :sync_id, :table_info
  ]
end

defmodule OrderSerializer.Order do
  @derive {JSON.Encoder, only: [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed, :billed, :mode_of_payment,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee,
    :discount, :estimated_preparation_time, :estimated_delivery_time,
    :delivery
  ]}
  defstruct [
    :_id, :restaurant, :table_order, :menu, :order_type, :timestamp, :items,
    :order_counter, :no_of_guests, :completed, :billed, :mode_of_payment,
    :total_items, :last_action_datetime, :active, :t,
    :total, :subtotal, :vat, :service_fee, :flat_person_fee, :home_delivery_fee, :discount,
    :estimated_preparation_time, :estimated_delivery_time, :delivery,
    :item_classification, :unbilled_amount
  ]
end
