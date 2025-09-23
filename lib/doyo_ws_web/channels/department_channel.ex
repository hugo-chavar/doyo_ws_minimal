defmodule DoyoWsWeb.DepartmentChannel do
  use DoyoWsWeb, :channel
  require Logger


  @impl true
  def join("department:" <> rest, _params, socket) do
    case String.split(rest, ":", parts: 2) do
      [restaurant_id, department_id] ->
        if valid_params?(restaurant_id, department_id) do
          # TODO: Check if restaurant exists and user has permission
          send(self(), {:after_department_join, restaurant_id, department_id})
          {:ok, socket}
        else
          Logger.warning("Rejected invalid department: #{department_id} restaurant_id: #{restaurant_id}")
          {:error, %{reason: "invalid_department"}}
        end
      _ ->
        Logger.warning("Invalid deparment topic format: #{rest}")
        {:error, %{reason: "invalid_format"}}
    end
  end

  @impl true
  def handle_info({:after_deparment_join, restaurant_id, department_id}, socket) do
    orders = DoyoWs.OrderService.get_by_restaurant(restaurant_id)

    department_detail = OrderSerializer.serialize_department_detail(orders, department_id)
    push(socket, "update", department_detail)

    {:noreply, socket}
  end

  defp valid_params?(rid, did) when is_binary(rid) and is_binary(did) do
    String.match?(rid, ~r/\A[[:digit:]]+\z/) and String.match?(did, ~r/\A[[:digit:]]+\z/)
  end
end
