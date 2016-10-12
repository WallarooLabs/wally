use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/resilience"
use "wallaroo/messages"

actor Step is ResilientOrigin
  let _runner: Runner
  let _hwm: HighWaterMarkTable = HighWaterMarkTable(10)
  let _lwm: LowWaterMarkTable = LowWaterMarkTable(10)
  let _translate: TranslationTable = TranslationTable(10)
  var _router: Router val = EmptyRouter
  let _metrics_reporter: MetricsReporter 
  let _outgoing_envelope: MsgEnvelope ref
  
  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso) =>
    _runner = consume runner
    _runner.set_buffer_target(this)
    _metrics_reporter = consume metrics_reporter
    _outgoing_envelope = MsgEnvelope(this, 0, None, 0, 0)

  fun send_watermark() =>
    //TODO: receive watermark, flush buffers and send another watermark
    None

  be update_router(router: Router val) =>
    _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    envelope: MsgEnvelope val) =>
    //TODO: make outgoing envelope
    //TODO: pass incoming envelope
    let is_finished = _runner.run[D](metric_name, source_ts, data, _outgoing_envelope, _router)
    // Process envelope if we're done
    // Note: We do the bookkeeping _after_ handing the computation result
    //       to the next Step.
    if is_finished then
      _bookkeeping(envelope)
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end
    
  be replay_log_entry(log_entry: LogEntry val) =>
    _runner.replay_log_entry(log_entry)

  be replay_finished() =>
    //TODO: clear deduplication logs
    None

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

  fun ref _bookkeeping(inEnvelope: MsgEnvelope val,
    outEnvelope: MsgEnvelope val)
  =>
    """
    Process envelope and keep track of things
    """
    // keep track of messages we've received from upstream
    _hwm.update(inEnvelope.origin_tag , inEnvelope.route_id, inEnvelope.seq_id)
    // keep track of mapping between incoming / outgoing seq_id
   _translate.update(inEnvelope.seq_id, outEnvelope.seq_id)

    
interface StepBuilder
  fun id(): U128

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag

// trait ThroughStepBuilder[In: Any val, Out: Any val] is StepBuilder

class StatelessStepBuilder
  let _runner_sequence_builder: RunnerSequenceBuilder val
  let _id: U128

  new val create(r: RunnerSequenceBuilder val, id': U128) =>
    _runner_sequence_builder = r
    _id = id'

  fun id(): U128 => _id

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag =>
    let runner = _runner_sequence_builder(MetricsReporter(pipeline_name, 
      metrics_conn))
    // let runner = ComputationRunner[In, Out](_computation_builder(),
      // consume next, MetricsReporter(pipeline_name, metrics_conn))
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn))
    step.update_router(next)
    step
