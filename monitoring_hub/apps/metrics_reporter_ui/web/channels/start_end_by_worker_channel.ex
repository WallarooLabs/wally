defmodule MetricsReporterUI.StartEndByWorkerChannel do
	use Phoenix.Channel

  def join("start-to-end-by-worker:" <> _metric_name, _message, socket) do
    {:ok, socket}
  end

end
