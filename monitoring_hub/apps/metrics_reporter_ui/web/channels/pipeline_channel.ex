defmodule MetricsReporterUI.PipelineChannel do
	use Phoenix.Channel

  def join("pipeline:" <> _metric_name, _message, socket) do
    {:ok, socket}
  end

end
