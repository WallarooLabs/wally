defmodule MetricsReporterUI.AppConfigChannel do
	use Phoenix.Channel
  alias MonitoringHubUtils.Stores.AppConfigStore

  def join("app-config:" <> _app_name, _message, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    push_app_config(socket)
    {:noreply, socket}
  end

  defp push_app_config(socket) do
    "app-config:" <> app_name = socket.topic
    {:ok, app_config} = AppConfigStore.get_or_create_app_config(app_name)
    push socket, "app-config", app_config
  end
end
