use "buffy/metrics"

class MetricsMonitoringHubHandler is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: MetricsOutputActor tag

  new val create(encoder': MetricsCollectionOutputEncoder val,
             output': MetricsOutputActor tag) =>
    encoder = encoder'
    output = output'

  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    output.send(MetricsCategories.sinks(),
                      String.from_array(encoder.encode_sinks(sinks, period)))
    output.send(MetricsCategories.boundaries(),
                           String.from_array(
                            encoder.encode_boundaries(boundaries,
                                                      period)))
    output.send(MetricsCategories.steps(),
                      String.from_array(encoder.encode_steps(steps, period)))
