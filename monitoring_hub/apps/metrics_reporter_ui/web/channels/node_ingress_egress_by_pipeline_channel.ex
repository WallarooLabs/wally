defmodule MetricsReporterUI.NodeIngressEgressByPipelineChannel do
	use Phoenix.Channel

	def join("node-ingress-egress-by-pipeline:" <> _metric_name, _message, socket) do
    {:ok, socket}
	end

end
