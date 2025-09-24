defmodule DoyoWs.TableReservationService do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_by_restaurant(restaurant_id) do
    case @redis_client.hvals("table_reservations_#{restaurant_id}") do
      {:ok, table_reservations_list} ->
        table_reservations_list
        |> Enum.map(&JSON.decode/1)
        |> Enum.filter(fn
          {:ok, _table_reservations} -> true
          {:error, _} -> false
        end)
        |> Enum.map(fn {:ok, table_reservation} -> table_reservation end)

      {:error, reason} ->
        Logger.error("Error get table_reservations by restaurant id #{restaurant_id}. Reason: #{reason}")
    end
  end

  def get_by_table(restaurant_id, table_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn reservation -> reservation["table_order"]["id"] == table_id end)
  end

end
