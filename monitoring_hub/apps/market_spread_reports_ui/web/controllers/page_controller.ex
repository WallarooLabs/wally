defmodule MarketSpreadReportsUI.PageController do
  use MarketSpreadReportsUI.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
