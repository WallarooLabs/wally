use "buffy/metrics"

class MetricsMonitoringHubHandler is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: MonitoringHubOutput

  new create(encoder': MetricsCollectionOutputEncoder val,
             output': MonitoringHubOutput) =>
    encoder = encoder'
    output = output'

  fun ref handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    output.send_sinks(String.from_array(encoder.encode_sinks(sinks, period)))
    output.send_boundaries(String.from_array(encoder.encode_boundaries(boundaries,
      period)))
    output.send_steps(String.from_array(encoder.encode_steps(steps, period)))
