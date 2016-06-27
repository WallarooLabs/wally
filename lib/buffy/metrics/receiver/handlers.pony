use "buffy/metrics"

class MetricsOutputHandler is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: MetricsOutputActor tag
  let app_name: String val

  new val create(encoder': MetricsCollectionOutputEncoder val,
    output': MetricsOutputActor tag, app_name': String val)
  =>
    encoder = encoder'
    output = output'
    app_name = app_name'

  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    if sinks.size() > 0 then
      output(encoder.encode_sinks(sinks, period, app_name))
    end
    if boundaries.size() > 0 then
      output(encoder.encode_boundaries(boundaries, period, app_name))
    end
    if steps.size() > 0 then
      output(encoder.encode_steps(steps, period, app_name))
    end

