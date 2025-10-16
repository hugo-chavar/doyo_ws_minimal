defmodule DoyoWs.TableReservationService do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_by_restaurant(restaurant_id) do
    case @redis_client.hvals("tables_#{restaurant_id}") do
      {:ok, tables_list} ->
        tables_list
        |> Enum.map(&JSON.decode/1)
        |> Enum.filter(fn
          {:ok, _table} -> true
          {:error, _} -> false
        end)
        |> Enum.map(fn {:ok, table} -> table end)

      {:error, reason} ->
        Logger.error("Error get tables by restaurant id #{restaurant_id}. Reason: #{reason}")
    end
  end

  def get_by_table(restaurant_id, table_id) do
    get_by_restaurant(restaurant_id)
    |> Enum.filter(fn table -> table["id"] == table_id end)
  end

  def get_single_table(restaurant_id, table_id) do

    case get_by_table(restaurant_id, table_id) do
      [] -> %{}
      [hd | _tl] -> hd
    end

  end
end
