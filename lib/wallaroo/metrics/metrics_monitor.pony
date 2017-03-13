interface MetricsMonitor
  """
  MetricsMonitor

  Interface for hooking into a MetricsReporter and being able to
  monitor metrics via on_send prior to a send_metrics() call.
  """
  fun clone(): MetricsMonitor iso^

  fun ref on_send(metrics: MetricDataList val) =>
    """
    Hook for monitoring metrics prior to send_metrics() call.
    """
    None

class DefaultMetricsMonitor is MetricsMonitor

  fun clone(): DefaultMetricsMonitor iso^ =>
    recover DefaultMetricsMonitor end
