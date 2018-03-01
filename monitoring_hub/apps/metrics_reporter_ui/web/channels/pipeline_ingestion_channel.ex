defmodule MetricsReporterUI.PipelineIngestionChannel do
	use Phoenix.Channel

  def join("pipeline-ingestion:" <> _metric_name, _message, socket) do
    {:ok, socket}
  end

end
