defmodule DoyoWs.TableReservation do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_guests(restaurant_id, table_id) do
    case @redis_client.hvals("reservations_#{restaurant_id}") do
      # TODO implement
      {:ok, order_list} ->
        {:ok}
    end
    {:ok}
  end

end
