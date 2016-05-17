primitive MetricsCategories
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"


interface MetricsOutputActor
  be send(category: String, payload: Array[U8] val)

interface Retriever
  be retrieved(a: Array[String] iso)

interface Retrievable
  be retrieve(that: Retriever tag)

actor MetricsAccumulatorActor is (MetricsOutputActor & Retrievable)
  var data: Array[String] iso = recover iso Array[String] end

  be send(category: String, payload: (String val | Array[U8] val)) =>
    match payload
    | let s': String val =>
      data.push(s')
    | let s': Array[U8] val =>
      data.push(String.from_array(s'))
    end

  be retrieve(that: Retriever tag) =>
    let data' = data = recover iso Array[String] end
    that.retrieved(consume data')


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
