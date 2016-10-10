use "net"
use "time"
use "buffered"
use "collections"
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
          _runner.run[In](_pipeline_name, ingest_ts, input, _router)
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
    
// class StateSource[In: Any val, Out: Any val, State: Any #read]
//   let _pipeline_name: String
//   let _source_name: String
//   let _decoder: SourceDecoder[In] val
//   let _router: Router val
//   let _runner: Runner val
//   let _state_comp: StateComputation[In, Out, State] val
//   let _metrics_reporter: MetricsReporter

//   new iso create(name': String, decoder: SourceDecoder[In] val, 
//     router: Router val, runner: Runner iso,
//     state_comp: StateComputation[In, Out, State] val,
//     metrics_reporter: MetricsReporter iso,
//     initial_msgs: Array[Array[U8] val] val = 
//       recover Array[Array[U8] val] end) =>
//     _pipeline_name = name'
//     _source_name = _pipeline_name + " source"
//     _decoder = decoder
//     _router = router
//     _runner = consume runner
//     _state_comp = state_comp
//     _metrics_reporter = consume metrics_reporter
//     for msg in initial_msgs.values() do
//       process(msg)
//     end

//   fun name(): String val => _source_name

//   fun ref process(data: Array[U8] val) =>
//     let ingest_ts = Time.nanos()
//     try
//       // For recording metrics for filtered messages
//       let computation_start = Time.nanos()

//       match _decoder(consume data)
//       | let input: In =>
//         let processor = 
//           StateComputationWrapper[In, Out, State](input, _state_comp, _router)
//         _router.route[StateProcessor[State] val](_pipeline_name, ingest_ts, 
//           processor)
//       else
//         // If parser returns None, we're filtering the message out already
//         let computation_end = Time.nanos()

//         _metrics_reporter.step_metric(_source_name,
//           computation_start, computation_end)
//       end
//     else 
//       @printf[I32]((_source_name + ": Problem parsing source input\n").cstring())
//     end