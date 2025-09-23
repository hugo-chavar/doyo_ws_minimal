defmodule DoyoWsWeb.TableChannel do
  use DoyoWsWeb, :channel
  require Logger


  @impl true
  def join("table:" <> rest, _params, socket) do
    case String.split(rest, ":", parts: 2) do
      [restaurant_id, table_id] ->
        if valid_params?(restaurant_id, table_id) do
          # TODO: Check if restaurant exists and user has permission
          send(self(), {:after_table_join, restaurant_id, table_id})
          {:ok, socket}
        else
          Logger.warning("Rejected invalid table: #{table_id} restaurant_id: #{restaurant_id}")
          {:error, %{reason: "invalid_table"}}
        end
      _ ->
        Logger.warning("Invalid table topic format: #{rest}")
        {:error, %{reason: "invalid_format"}}
    end
  end

  @impl true
  def handle_info({:after_table_join, restaurant_id, table_id}, socket) do
    orders = DoyoWs.OrderService.get_by_table(restaurant_id, table_id)
    single_table_details = OrderSerializer.serialize_single_table(orders, table_id)
    push(socket, "update", single_table_details)

    {:noreply, socket}
  end

  defp valid_params?(restaurant_id, table_id) when is_binary(restaurant_id) and is_binary(table_id) do
    String.match?(restaurant_id, ~r/\A[[:digit:]]+\z/) and String.match?(table_id, ~r/\A[[:digit:]]+\z/)
  end

end
