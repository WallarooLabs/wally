use "promises"
use "sendence/bytes"
use "net"

primitive MetricsCategories
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

interface MetricsOutputActor
  be apply(payload: ByteSeq)
  be dispose()

interface MetricsCollectionOutputHandler
  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64)
  fun dispose(): None val => None

actor MetricsAccumulatorActor is MetricsOutputActor
  let _wb: WriteBuffer = WriteBuffer
  let _promise: Promise[Array[ByteSeq] val]

  new create(promise: Promise[Array[ByteSeq] val]) =>
    _promise = promise

  be apply(payload: ByteSeq) =>
    if payload.size() > 0 then
      _wb.u32_be(payload.size().u32())
      _wb.write(payload)
    end

  be written() =>
    _promise(_wb.done())

  be dispose() => None

class MetricsStringAccumulator is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: MetricsOutputActor tag
  let app_name: String

  new iso create(encoder': MetricsCollectionOutputEncoder val,
             output': MetricsOutputActor tag, app_name': String) =>
    encoder = encoder'
    output = output'
    app_name = app_name'

  fun dispose(): None val => None

  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    output(encoder.encode_sinks(sinks, period, app_name))
    output(encoder.encode_boundaries(boundaries, period, app_name))
    output(encoder.encode_steps(steps, period, app_name))

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
