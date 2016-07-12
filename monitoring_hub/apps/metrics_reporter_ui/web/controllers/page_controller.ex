defmodule MetricsReporterUI.PageController do
  use MetricsReporterUI.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
