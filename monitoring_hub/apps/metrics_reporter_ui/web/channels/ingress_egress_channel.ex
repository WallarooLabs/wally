defmodule MetricsReporterUI.IngressEgressChannel do
	use Phoenix.Channel

	def join("ingress-egress:" <> _metric_name, _message, socket) do
    {:ok, socket}
	end

end
