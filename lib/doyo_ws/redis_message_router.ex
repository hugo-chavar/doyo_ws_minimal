defmodule DoyoWs.RedisMessageRouter do
  require Logger
  alias DoyoWs.OrderService
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
    {:ok, %{
      "rid" => restaurant_id,
      "order_items" => order_items
      }
    } = JSON.decode(payload)
    order_ids = Enum.map(order_items, & &1["order_id"])
    item_ids = Enum.flat_map(order_items, & &1["items"])

    restaurant_orders = OrderService.get_by_restaurant(restaurant_id)
    payload_orders =
      restaurant_orders
      |> Enum.filter(& &1._id in order_ids)

    payload_orders_by_table =
      payload_orders
      |> OrderSerializer.Aggregator.group_orders_by_table()

    # update order status channel
    Enum.each(payload_orders, fn order ->
      broadcast_order_update(restaurant_id, order._id, order)
    end)

    # update single table channels
    Enum.each(payload_orders_by_table, fn {table_id, table_orders} ->
      updated_items =
        table_orders
        |> Enum.flat_map(fn order ->
          Enum.filter(order.items, & &1._id in item_ids)
        end)
      if not Enum.empty?(updated_items) do
        single_table_topic = "table:#{restaurant_id}:#{table_id}"
        broadcast_update(single_table_topic, %{items: updated_items})
      end
    end)

    # update all tables channel
    updated_tables = Enum.map(payload_orders_by_table, & elem(&1,0))

    restaurant_orders_in_updated_tables =
      restaurant_orders
      |> Enum.filter(fn order -> order.table_order.id in updated_tables end)

    updated_tables_detail = OrderSerializer.serialize_all_tables(restaurant_orders_in_updated_tables)
    all_tables_topic = "tables:#{restaurant_id}"
    broadcast_update(all_tables_topic, updated_tables_detail)

    payload_orders_only_updated_items = Enum.map(payload_orders, fn order ->
      %{order | items: Enum.filter(order.items, fn item ->
        item._id in item_ids
      end)}
    end)
    items_by_dept = OrderSerializer.Aggregator.group_items_by_department(payload_orders_only_updated_items)
    Enum.each(items_by_dept, fn {dept_id, dept_detail} ->
      dept_topic = "department:#{restaurant_id}:#{dept_id}"
      broadcast_update(dept_topic, dept_detail)
    end)
  end

  def route("update_table_guests", payload) do
    {:ok, %{"rid" => _restaurant_id, "tid" => _table_id, "mid" => _menu_id}} = JSON.decode(payload)
    # TODO find the table and send the update to all_tables and single_table
  end

  def route(channel, payload) do
    Logger.warning("No handler defined for channel #{channel}, payload: #{payload}")
  end

  defp broadcast_update(topic, payload) do
    Endpoint.broadcast(topic, "update", payload)
    Logger.info("Broadcasted to #{topic}")
  end

  defp broadcast_order_update(rid, order_id) do
    order = OrderService.get_by_order_id(rid, order_id)
    broadcast_order_update(rid, order_id, order)
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
end
