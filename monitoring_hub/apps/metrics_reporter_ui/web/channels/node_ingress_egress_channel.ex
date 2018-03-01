defmodule MetricsReporterUI.NodeIngressEgressChannel do
	use Phoenix.Channel

	def join("node-ingress-egress:" <> _metric_name, _message, socket) do
    {:ok, socket}
	end

end
