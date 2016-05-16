interface MetricsCollectionOutputHandler
  fun ref handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64)

class MetricsStringAccumulator is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: Array[String] = Array[String]

  new create(encoder': MetricsCollectionOutputEncoder val) =>
    encoder = encoder'

  fun ref handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    output.push(String.from_array(encoder.encode_sinks(sinks, period)))
    output.push(String.from_array(encoder.encode_boundaries(boundaries,
      period)))
    output.push(String.from_array(encoder.encode_steps(steps, period)))

//class MetricsMonitoringHubHandler is MetricsCollectionOutputHandler

