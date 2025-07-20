defmodule DoyoWsWeb.ErrorJSONTest do
  use DoyoWsWeb.ConnCase, async: true

  test "renders 404" do
    assert DoyoWsWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert DoyoWsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
