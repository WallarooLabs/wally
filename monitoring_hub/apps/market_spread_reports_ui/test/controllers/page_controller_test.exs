defmodule MarketSpreadReportsUI.PageControllerTest do
  use MarketSpreadReportsUI.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Buffy: Market Spread Reports"
  end
end
