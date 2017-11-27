defmodule MetricsReporterUI.ApplicationsChannel do
	use Phoenix.Channel
  alias MonitoringHubUtils.Stores.AppConfigStore

  def join("applications", _message, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    push_app_names(socket)
    {:noreply, socket}
  end

  defp push_app_names(socket) do
    {:ok, app_names} = AppConfigStore.get_app_names
    push socket, "app-names", %{"app_names" => app_names}
  end
end
