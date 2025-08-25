defmodule DoyoWsWeb.OrderChannelTest do
  use DoyoWsWeb.ChannelCase

  import Mox
  setup :verify_on_exit!

  alias DoyoWs.Redis.RedisMock

  # ------------------------------------------------------------------
  # Shared setup: valid order join
  # ------------------------------------------------------------------
  setup do
    # Default stub for RedisMock
    RedisMock
    |> stub(:subscribe, fn _channel -> {:ok, make_ref()} end)
    |> stub(:get, fn _key -> {:ok, nil} end)

    {:ok, _, socket} =
      DoyoWsWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:60c72b1f9b3e6c001c8c0b1a")

    %{socket: socket}
  end

  # ------------------------------------------------------------------
  # Legacy channel tests
  # ------------------------------------------------------------------

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to order:topic", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end

  # ------------------------------------------------------------------
  # New join validation tests
  # ------------------------------------------------------------------

  test "join/3 validation accepts a valid ObjectId" do
    RedisMock
    |> expect(:get, fn "json_order_60c72b1f9b3e6c001c8c0b1a" -> {:ok, nil} end)

    {:ok, _, _socket} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:60c72b1f9b3e6c001c8c0b1a", %{})
  end

  test "join/3 validation rejects invalid ObjectIds" do
    {:error, %{reason: "invalid_order_id"}} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:ZZZZZZZZZZZZZZZZZZZZZZZZ", %{})

    {:error, %{reason: "invalid_order_id"}} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:abc123", %{})
  end

  test "join/3 validation rejects non-order topics" do
    {:error, %{reason: "invalid_order_id"}} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "something_else:123", %{})
  end

  # ------------------------------------------------------------------
  # Handle_info tests
  # ------------------------------------------------------------------

  test "after_join pushes update when Redis has cached JSON", _ do
    payload = %{"id" => "60c72b1f9b3e6c001c8c0b1a", "status" => "ready"}
    json_payload = Jason.encode!(payload)

    RedisMock
    |> expect(:get, fn "json_order_60c72b1f9b3e6c001c8c0b1a" -> {:ok, json_payload} end)

    {:ok, _, _} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:60c72b1f9b3e6c001c8c0b1a", %{})

    assert_push "update", ^payload
  end

  test "after_join logs error and does not push when Redis.get fails", _ do
    RedisMock
    |> expect(:get, fn "json_order_60c72b1f9b3e6c001c8c0b1a" ->
      {:error, %Redix.ConnectionError{reason: :closed}}
    end)

    {:ok, _, _} =
      socket(DoyoWsWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(DoyoWsWeb.OrderChannel, "order:60c72b1f9b3e6c001c8c0b1a", %{})

    # Assert that no "update" message was pushed
    refute_push "update", _any
  end
end
