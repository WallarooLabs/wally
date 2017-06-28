defmodule MetricsReporterUI.PageControllerTest do
  use MetricsReporterUI.ConnCase
  # FIX ME: Comment back in once Erlang/Elixir are pinned on OSX
  #	currently fails due to Erlang 20 being installed by Travis CI
  # and :crypto.rand_bytes being deprecated
  # test "GET /", %{conn: conn} do
  #   conn = get conn, "/"
  #   assert html_response(conn, 200) =~ "Metrics Reporter"
  # end
end
