defmodule DoyoWs.DepartmentDetails do
  require Logger
  @redis_client Application.compile_env!(:doyo_ws, :redis_impl)

  def get_details(restaurant_id, department_id) do
    #get all orders from redis
    case @redis_client.hvals("orders_#{restaurant_id}") do

      {:ok, order_list} ->
        table_details = Enum.each(order_list, fn order_str ->
          case Jason.decode(order_str) do
            # add all the necesary fields
            {:ok, %{"active" => true, "completed" => false, "items" => items}} ->
              # write here all the logic
              Logger.info("Payload is ok ")
            {:ok, _payload} ->
              Logger.info("Payload is wrong #{inspect(_payload)}")
          end
        end)
        {:ok, %{"table_details" => table_details}}
      {:error, reason} ->
        {:error, reason}
    end

  end

end
