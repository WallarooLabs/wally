defmodule MetricsReporterUI.StepChannel do
  use Phoenix.Channel

  def join("step:" <> _step_name, _message, socket) do
    {:ok, socket}
  end

end
