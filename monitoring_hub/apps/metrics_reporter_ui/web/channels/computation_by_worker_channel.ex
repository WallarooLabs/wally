defmodule MetricsReporterUI.ComputationByWorkerChannel do
  use Phoenix.Channel

  def join("computation-by-worker:" <> _computation_name, _message, socket) do
    {:ok, socket}
  end

end
