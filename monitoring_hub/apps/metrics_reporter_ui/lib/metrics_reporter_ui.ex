defmodule MetricsReporterUI do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(MetricsReporterUI.Endpoint, []),
      supervisor(PhoenixTCP.Supervisor, [__MODULE__, MetricsReporterUI.Endpoint]),
      supervisor(MonitoringHubUtils.MessageLog.Supervisor, []),
      supervisor(MetricsReporterUI.LatencyStatsBroadcaster.Supervisor, []),
      supervisor(MetricsReporterUI.ThroughputsBroadcaster.Supervisor, []),
      supervisor(MetricsReporterUI.ThroughputStatsBroadcaster.Supervisor, []),
      # Here you could define other workers and supervisors as children
      # worker(MetricsReporterUI.Worker, [arg1, arg2, arg3]),
      worker(MonitoringHubUtils.Stores.AppConfigStore, []),
      worker(MetricsReporterUI.AppNamesBroadcaster, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MetricsReporterUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MetricsReporterUI.Endpoint.config_change(changed, removed)
    :ok
  end
end
