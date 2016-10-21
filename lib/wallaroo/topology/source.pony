use "net"
use "time"
use "buffered"
use "collections"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"

interface BytesProcessor
  fun ref process(data: Array[U8 val] iso)

class Source[In: Any val]
  let _decoder: SourceDecoder[In] val
  let _pipeline_name: String
  let _source_name: String
  let _runner: Runner
  let _router: Router val
  let _metrics_reporter: MetricsReporter
  var _count: USize = 0

  new iso create(pipeline_name: String, decoder: SourceDecoder[In] val, 
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso) 
  =>
    _decoder = decoder
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _metrics_reporter = consume metrics_reporter
    _runner = runner_builder(_metrics_reporter.clone())
    _router = router

  fun ref process(data: Array[U8 val] iso) =>
    let ingest_ts = Time.nanos()
    let computation_start = Time.nanos()

    let is_finished = 
      try
        match _decoder(consume data)
        | let input: In =>
          _runner.run[In](_pipeline_name, ingest_ts, input, None, 
            _router)
        else
          true
        end
      else
        true
      end

    let computation_end = Time.nanos()

    _metrics_reporter.step_metric(_source_name,
      computation_start, computation_end)
    if is_finished then
      _metrics_reporter.pipeline_metric(_pipeline_name, ingest_ts)
    end

trait BytesProcessorBuilder
  fun apply(router: Router val, reporter: MetricsReporter iso): 
    BytesProcessor iso^

class SourceBuilder[In: Any val] is BytesProcessorBuilder
  let _pipeline_name: String
  let _decoder: SourceDecoder[In] val
  let _runner_builder: RunnerBuilder val

  new val create(name: String, decoder: SourceDecoder[In] val,
    runner_builder: RunnerBuilder val = RouterRunnerBuilder) =>
    _pipeline_name = name
    _decoder = decoder
    _runner_builder = runner_builder

  fun apply(router: Router val, reporter: MetricsReporter iso): 
    BytesProcessor iso^ 
  =>
    Source[In](_pipeline_name, _decoder, _runner_builder, router, 
      consume reporter)

class SourceData
  let _builder: BytesProcessorBuilder val
  let _address: Array[String] val

  new val create(b: BytesProcessorBuilder val, a: Array[String] val) =>
    _builder = b
    _address = a

  fun builder(): BytesProcessorBuilder val => _builder
  fun address(): Array[String] val => _address

