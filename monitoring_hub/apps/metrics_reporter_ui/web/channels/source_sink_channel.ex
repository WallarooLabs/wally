defmodule MetricsReporterUI.SourceSinkChannel do
	use Phoenix.Channel

  def join("source-sink:" <> _metric_name, _message, socket) do
    {:ok, socket}
  end

end
