defmodule MetricsReporterUI.StartEndChannel do
	use Phoenix.Channel

  def join("start-to-end:" <> _metric_name, _message, socket) do
    {:ok, socket}
  end

end
