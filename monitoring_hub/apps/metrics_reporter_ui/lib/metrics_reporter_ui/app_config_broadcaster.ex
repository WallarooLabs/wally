defmodule MetricsReporterUI.AppConfigBroadcaster do
	use GenServer
	require Logger
  alias MonitoringHubUtils.Stores.AppConfigStore

  def start_link(app_name) do
    GenServer.start_link(__MODULE__, [app_name: app_name], name: via_tuple(app_name))
  end

  def init([app_name: app_name]) do
    {:ok, app_config} = AppConfigStore.get_or_create_app_config(app_name)
    send(self(), :watch_app_config)
    {:ok, %{app_name: app_name, app_config: app_config}}
  end

  def handle_info(:watch_app_config, %{app_name: app_name, app_config: app_config} = state) do
    :timer.sleep(1000)
    {:ok, updated_app_config} = AppConfigStore.get_or_create_app_config(app_name)
    if (app_config != updated_app_config) do
      MetricsReporterUI.Endpoint.broadcast! "app-config:" <> app_name, "app-config", updated_app_config
    end
    send(self(), :watch_app_config)
    {:noreply, put_in(state, [:app_config], updated_app_config)}
  end

  defp via_tuple(app_name) do
    {:via, :gproc, {:n, :l, {:app_config_watcher, app_name}}}
  end
end
