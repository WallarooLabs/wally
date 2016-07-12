defmodule MetricsReporterUI.PageControllerTest do
  use MetricsReporterUI.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Metrics Reporter"
  end
end
