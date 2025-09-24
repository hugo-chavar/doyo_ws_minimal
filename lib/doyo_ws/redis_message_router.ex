defmodule DoyoWs.RedisMessageRouter do
  require Logger
  alias DoyoWs.OrderService

  def route("orders", payload) do
    case JSON.decode(payload) do
      {:ok, %{"order_id" => order_id, "data" => inner_data}} when is_binary(order_id) ->
        topic = "order:#{order_id}"
        DoyoWsWeb.Endpoint.broadcast(topic, "update", inner_data)
        Logger.info("Broadcasted to #{topic}: #{inspect(inner_data)}")

      {:ok, decoded} ->
        Logger.warning("Received orders message without order_id: #{inspect(decoded)}")

      {:error, reason} ->
        Logger.error("Failed to decode order message: #{inspect(reason)} - #{payload}")
    end
  end

  def route("table_details", payload) do
    # Add logic for table_details later
    Logger.info("Stub: Received table_details payload #{payload}")
  end

  def route("department_details", payload) do
    # Add logic for department_details later
    Logger.info("Stub: Received department_details payload #{payload}")
  end

  def route("counter_" <> type, payload) do
    {:ok, %{"rid" => restaurant_id}} = JSON.decode(payload)
    Logger.info("Stub: Received #{type}_counter for restaurant #{restaurant_id}")
    {:ok, count} = DoyoWs.OrderItemCounter.get_counter(restaurant_id, type)
    topic = "counter:#{type}:#{restaurant_id}"
    DoyoWsWeb.Endpoint.broadcast(topic, "update", count)
    Logger.info("Broadcasted to #{topic}: #{count}")

  end

  def route("items_update", payload) do
    {:ok, %{
      "rid" => restaurant_id,
      "order_items" => order_items
      }
    } = JSON.decode(payload)

    restaurant_orders = OrderService.get_by_restaurant(restaurant_id)
    # TODO
    # order_ids = Enum.map(order_items, & &1["order_id"])

    #For each updated order/item
    # get all items in a list and update the
    # => get all restaurant orders (keep restaurant_orders), filter by ids => keep payload_orders in a variable,
    # then filter the items per order
    ### From here the logic can be extracted so it can be reused
    # => group by table id (rem: all items from the same order have the same table_id) => this is for many orders "Call all" ..
    # => broadcast to single tables the list of items

    # Filter restaurant_orders keeping changed table_id =>
    # => group by table_id and broadcast to all tables order_serializer.serialize_all_tables

    # TODO: write instuctions for department details. ..



  end

  def route("update_table_guests", payload) do
    {:ok, %{"rid" => _restaurant_id, "tid" => _table_id, "mid" => _menu_id}} = JSON.decode(payload)
    # TODO find the table and send the update to all_tables and single_table
  end

  def route(channel, payload) do
    Logger.warning("No handler defined for channel #{channel}, payload: #{payload}")
  end
end
