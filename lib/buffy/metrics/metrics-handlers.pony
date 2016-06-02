use "promises"
use "sendence/bytes"
use "debug"

primitive MetricsCategories
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

interface MetricsOutputActor
  be send(category: String, payload: Array[U8 val] val)

actor MetricsAccumulatorActor is MetricsOutputActor
  var _output: String ref = String
  let _promise: Promise[String]

  new create(promise: Promise[String]) =>
    Debug("create")
    _promise = promise
    _collect("hello worldsdfsdfs")

  fun ref _collect(data: ByteSeq) =>
    Debug("collect")
    _output.append(data)

  be send(category: String val, payload: Array[U8 val] val) =>
    Debug("send")
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
    Debug("written")
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
    output.send(MetricsCategories.sinks(),
                encoder.encode_sinks(sinks, period))
    output.send(MetricsCategories.boundaries(),
                encoder.encode_boundaries(boundaries, period))
    output.send(MetricsCategories.steps(),
                encoder.encode_steps(steps, period))
