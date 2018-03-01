defmodule MetricsReporterUI.ComputationChannel do
  use Phoenix.Channel

  def join("computation:" <> _computation_name, _message, socket) do
    {:ok, socket}
  end

end
