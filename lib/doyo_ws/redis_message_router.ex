defmodule DoyoWs.RedisMessageRouter do
  require Logger
  alias DoyoWs.OrderService
  alias DoyoWs.TableReservationService
  alias DoyoWsWeb.Endpoint

  def route("orders", payload) do
    case JSON.decode(payload) do
      {
        :ok,
        %{"rid" => rid, "order_id" => order_id, "data" => inner_data}
      } when is_binary(order_id) ->
        topic = "order:#{rid}:#{order_id}"
        broadcast_update(topic, inner_data)
      {
        :ok,
        %{"rid" => rid, "order_id" => order_id}
      } when is_binary(order_id) ->
        broadcast_order_update(rid, order_id)
      {:ok, decoded} ->
        Logger.warning("Received orders message without order_id: #{inspect(decoded)}")

      {:error, reason} ->
        Logger.error("Failed to decode order message: #{inspect(reason)} - #{payload}")
    end
  end


  def route("counter_" <> type, payload) do
    {:ok, %{"rid" => restaurant_id}} = JSON.decode(payload)
    Logger.info("Stub: Received #{type}_counter for restaurant #{restaurant_id}")
    {:ok, count} = DoyoWs.OrderItemCounter.get_counter(restaurant_id, type)
    topic = "counter:#{type}:#{restaurant_id}"
    broadcast_update(topic, count)

  end

def route("order_items_update", payload) do
  {:ok, decoded_payload} = JSON.decode(payload)
  process_order_items_update(decoded_payload)
end

  def route("guests_update", payload) do
    {:ok, %{"rid" => restaurant_id, "tid" => table_id}} = JSON.decode(payload)
    table = TableReservationService.get_single_table(restaurant_id, table_id)
    IO.inspect(table, label: "Data before access")

    payload_data = %{
      guests: table["guests"],
      table_order: %{id: table["id"]}
    }

    table_payload = %{
      update_guests: true,
      data: payload_data
    }

    all_tables_topic = "tables:#{restaurant_id}"
    Logger.info("Route: guests_update broadcast 1")
    broadcast_update(all_tables_topic, table_payload)

    single_table_topic = "table:#{restaurant_id}:#{table_id}"
    Logger.info("Route: guests_update broadcast 2")
    broadcast_update(single_table_topic, table_payload)

    orders = OrderService.get_by_table(restaurant_id, table_id)

    dept_ids =
      orders
      |> Enum.flat_map(& &1.items)
      |> Enum.filter(fn item -> not item.completed end)
      |> Enum.map(fn item -> item.product.category.department.id end) |> Enum.uniq()

    dept_payload = %{
      tables: [
        %{
          table_id: table_id,
          update_guests: true,
          data: payload_data
        }
      ]
    }
    Enum.each(dept_ids, fn dept_id ->
      dept_topic = "department:#{restaurant_id}:#{dept_id}"
      Logger.info("Route: guests_update broadcast 3")
      broadcast_update(dept_topic, %{ tables: dept_payload})
    end)
  end

  def route(channel, payload) do
    Logger.warning("No handler defined for channel #{channel}, payload: #{payload}")
  end

  defp broadcast_update(topic, payload) do
    Endpoint.broadcast(topic, "update", payload)
    Logger.info("Broadcasted to #{topic}")
  end

  defp broadcast_order_update(rid, order_id) do
    # Only new orders are supposed to end here
    order = OrderService.get_by_order_id(rid, order_id)
    broadcast_order_update(rid, order_id, order)
    table_id = get_in(order, [:table_order, :id])
    if table_id do
      single_table_topic = "table:#{rid}:#{table_id}"
      Logger.info("Broadcast new order to #{single_table_topic}")
      broadcast_update(single_table_topic, order)
    else
      Logger.error("Broadcast new order failed. Table Id is nil for order #{order_id} rest #{rid}")
    end

  end

  defp broadcast_order_update(rid, order_id, order) do
    topic = "order:#{rid}:#{order_id}"
    broadcast_update(topic, order)
    if order.t != "Other" do
      type = String.downcase(order.t)
      Logger.info("Update counter #{type} for restaurant #{rid}")
      {:ok, count} = DoyoWs.OrderItemCounter.get_counter(rid, type)
      topic = "counter:#{type}:#{rid}"
      broadcast_update(topic, count)
    end
  end

  defp process_order_items_update(%{
    "rid" => restaurant_id,
    "order_items" => order_items
  } = payload) do
    Logger.info("Route: order_items_update for restaurant #{restaurant_id} items: #{inspect(order_items)}")

    is_new = Map.get(payload, "new", false)
    {order_ids, item_ids} = extract_payload_data(order_items)
    restaurant_orders = OrderService.get_by_restaurant(restaurant_id)

    payload_orders = filter_orders_by_ids(restaurant_orders, order_ids)
    payload_orders_by_table = OrderSerializer.Aggregator.group_orders_by_table(payload_orders)

    # Broadcast order updates for each individual order
    broadcast_order_updates(restaurant_id, payload_orders)

    # Broadcast table updates (skip if new items are being created)
    if not is_new do
      broadcast_table_updates(restaurant_id, payload_orders_by_table, item_ids)
    end

    # Broadcast all tables overview
    broadcast_all_tables_update(restaurant_id, restaurant_orders, payload_orders_by_table)

    # Broadcast department updates
    broadcast_department_updates(restaurant_id, payload_orders, item_ids)
  end

  defp extract_payload_data(order_items) do
    order_ids = Enum.map(order_items, & &1["order_id"])
    item_ids = Enum.flat_map(order_items, & &1["items"])
    {order_ids, item_ids}
  end

  defp filter_orders_by_ids(restaurant_orders, order_ids) do
    Enum.filter(restaurant_orders, & &1._id in order_ids)
  end

  defp broadcast_order_updates(restaurant_id, payload_orders) do
    Enum.each(payload_orders, fn order ->
      Logger.info("Route: order_items_update broadcast 1")
      broadcast_order_update(restaurant_id, order._id, order)
    end)
  end

  defp broadcast_table_updates(restaurant_id, payload_orders_by_table, item_ids) do
    Enum.each(payload_orders_by_table, fn {table_id, table_orders} ->
      updated_items = extract_updated_items(table_orders, item_ids)

      if Enum.any?(updated_items) do
        single_table_topic = "table:#{restaurant_id}:#{table_id}"
        Logger.info("Route: order_items_update broadcast 2")
        broadcast_update(single_table_topic, %{items: updated_items})
      end
    end)
  end

  defp extract_updated_items(table_orders, item_ids) do
    table_orders
    |> Enum.flat_map(fn order ->
      Enum.filter(order.items, & &1._id in item_ids)
    end)
  end

  defp broadcast_all_tables_update(restaurant_id, restaurant_orders, payload_orders_by_table) do
    updated_tables = Enum.map(payload_orders_by_table, & elem(&1, 0))

    restaurant_orders_in_updated_tables =
      restaurant_orders
      |> Enum.filter(fn order -> order.table_order.id in updated_tables end)

    updated_tables_detail = OrderSerializer.serialize_all_tables(restaurant_orders_in_updated_tables)
    all_tables_topic = "tables:#{restaurant_id}"
    Logger.info("Route: order_items_update broadcast 3")
    broadcast_update(all_tables_topic, %{details: updated_tables_detail})
  end

  defp broadcast_department_updates(restaurant_id, payload_orders, item_ids) do
    payload_orders_only_updated_items = filter_orders_to_updated_items(payload_orders, item_ids)
    items_by_dept = OrderSerializer.Aggregator.group_items_by_department(payload_orders_only_updated_items)

    Enum.each(items_by_dept, fn {dept_id, dept_detail} ->
      dept_topic = "department:#{restaurant_id}:#{dept_id}"
      Logger.info("Route: order_items_update broadcast 4")
      broadcast_update(dept_topic, %{tables: dept_detail})
    end)
  end

  defp filter_orders_to_updated_items(payload_orders, item_ids) do
    Enum.map(payload_orders, fn order ->
      %{order | items: Enum.filter(order.items, fn item ->
        item._id in item_ids
      end)}
    end)
  end
end
