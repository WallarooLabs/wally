use "promises"
use "sendence/bytes"
use "net"

primitive MetricsCategories
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

interface MetricsOutputActor
  be apply(category: String, payload: Array[U8 val] val)
  be dispose()

actor MetricsAccumulatorActor is MetricsOutputActor
  let _wb: WriteBuffer = WriteBuffer
  let _promise: Promise[Array[ByteSeq] val]

  new create(promise: Promise[Array[ByteSeq] val]) =>
    _promise = promise

  be apply(category: String val, payload: Array[U8 val] val) =>
    _wb.u32_be(category.size().u32())
    _wb.write(category)
    _wb.u32_be(payload.size().u32())
    _wb.write(payload)

  be written() =>
    _promise(_wb.done())

  be dispose() => None

interface MetricsCollectionOutputHandler
  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64)
  fun dispose(): None val => None

class MetricsStringAccumulator is MetricsCollectionOutputHandler
  let encoder: MetricsCollectionOutputEncoder val
  let output: MetricsOutputActor tag

  new create(encoder': MetricsCollectionOutputEncoder val,
             output': MetricsOutputActor tag) =>
    encoder = encoder'
    output = output'

  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64) =>
    output(MetricsCategories.sinks(),
      encoder.encode_sinks(sinks, period))
    output(MetricsCategories.boundaries(),
      encoder.encode_boundaries(boundaries, period))
    output(MetricsCategories.steps(),
      encoder.encode_steps(steps, period))
