defmodule MetricsReporterUI.AppNamesBroadcaster do
	use GenServer

  alias MonitoringHubUtils.Stores.AppConfigStore

  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: :app_names_broadcaster)
  end

  def init([]) do
    send(self(), :broadcast_app_names)
    {:ok, %{}}
  end

  def handle_info(:broadcast_app_names, state) do
    :timer.sleep(5000)
    get_and_broadcast_app_names()
    send(self(), :broadcast_app_names)
    {:noreply, state}
  end

  defp get_and_broadcast_app_names do
    {:ok, app_names} = AppConfigStore.get_app_names
    MetricsReporterUI.Endpoint.broadcast! "applications", "app-names", %{"app_names" => app_names}
  end
end
