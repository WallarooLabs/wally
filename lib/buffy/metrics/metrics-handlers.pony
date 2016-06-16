use "promises"
use "sendence/bytes"

primitive MetricsCategories
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

interface MetricsOutputActor
  be apply(category: String, payload: Array[U8 val] val)

actor MetricsAccumulatorActor is MetricsOutputActor
  var _output: String ref = String
  let _promise: Promise[String]

  new create(promise: Promise[String]) =>
    _promise = promise

  fun ref _collect(data: Array[U8 val] val) =>
    _output.append(data)

  be apply(category: String val, payload: Array[U8 val] val) =>
    let c = Bytes.length_encode(category.array())
    let p = Bytes.length_encode(payload)
    let a: Array[U8 val] val =
      recover val
        let a: Array[U8 val] ref = recover Array[U8 val] end
        a.append(c).append(p)
        consume a
      end
    _collect(consume a)

  be written() =>
    let s: String = _output.clone()
    _promise(s)

interface MetricsCollectionOutputHandler
  fun handle(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64)

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
