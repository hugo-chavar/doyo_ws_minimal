defmodule DoyoWsWeb.CounterChannel do
  use DoyoWsWeb, :channel
  require Logger

  @impl true
  def join("counter:" <> rest, _params, socket) do
    case String.split(rest, ":", parts: 2) do
      [type, restaurant_id] ->
        if valid_params?(restaurant_id, type) do
          send(self(), {:after_counter_join, restaurant_id, type})
          {:ok, socket}
        else
          Logger.warning("Rejected invalid counter: #{type} restaurant_id: #{restaurant_id}")
          {:error, %{reason: "invalid_counter"}}
        end
      _ ->
        Logger.warning("Invalid counter topic format: #{rest}")
        {:error, %{reason: "invalid_format"}}
    end
  end

  @impl true
  def handle_info({:after_counter_join, restaurant_id, type}, socket) do
    # Fetch order counter from Redis
    case DoyoWs.OrderItemCounter.get_counter(restaurant_id, type) do
      {:ok, counter} ->
        push(socket, "update", counter)
      {:error, reason} ->
        Logger.error("Item counter get failed: #{inspect(reason)}")
        :ok
    end

    {:noreply, socket}
  end

  defp valid_params?(id, type) when is_binary(id) do
    String.match?(id, ~r/\A[[:digit:]]+\z/) and type in ["pos", "kiosk"]
  end

end
