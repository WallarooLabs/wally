use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"

// trait RunnableStep
//   be update_router(router: Router val)
//   be run[D: Any val](metric_name: String, source_ts: U64, data: D)
//   be dispose()

trait RunnableStep
  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128, 
    frac_ids: (Array[U64] val | None), seq_id: U64, route_id: U64)

actor Step is (RunnableStep & ResilientOrigin & CreditFlowProducer)
  let _runner: Runner
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _translate: TranslationTable = TranslationTable(10)
  let _origins: OriginSet = OriginSet(10)
  var _router: Router val
  let _metrics_reporter: MetricsReporter 
  var _seq_id: U64
  let _incoming_envelope: MsgEnvelope = MsgEnvelope(this, 0, None, 0, 0)
  let _outgoing_envelope: MsgEnvelope = MsgEnvelope(this, 0, None, 0, 0)
  
  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso,
    router: Router val = EmptyRouter) =>
    _runner = consume runner
    match _runner
    | let elb: EventLogBufferable =>
      elb.set_buffer_target(this)
    end
    _metrics_reporter = consume metrics_reporter
    _seq_id = 0
    _router = router
    
  be update_router(router: Router val) => _router = router

  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128, 
    frac_ids: (Array[U64] val | None), seq_id: U64, route_id: U64)
  =>
    _seq_id = _seq_id + 1
    _incoming_envelope.update(origin, msg_uid, frac_ids, seq_id, route_id)
    _outgoing_envelope.update(this, msg_uid, frac_ids, _seq_id)
    let is_finished = _runner.run[D](metric_name, source_ts, data,
      _incoming_envelope, _outgoing_envelope, this, _router)
    if is_finished then
      ifdef "resilience" then
        _bookkeeping(_incoming_envelope, _seq_id)
        // if Sink then _send_watermark()
      end
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end
    
  ///////////
  // RECOVERY
  
  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary
  be recovery_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128, 
    frac_ids: (Array[U64] val | None), seq_id: U64, route_id: U64)
  =>
    _seq_id = _seq_id + 1
    _incoming_envelope.update(origin, msg_uid, frac_ids, seq_id, route_id)
    _outgoing_envelope.update(this, msg_uid, frac_ids, _seq_id)
    // TODO: Reconsider how recovery_run works.  Used to call recovery_run()
    // on runner, but now runners don't implement that method.
    let is_finished = _runner.run[D](metric_name, source_ts, data,
      _incoming_envelope, _outgoing_envelope, this, _router)
    if is_finished then
      _bookkeeping(_incoming_envelope, _seq_id)
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end

  fun ref _hwm_get(): HighWatermarkTable =>
    _hwm
  
  fun ref _lwm_get(): LowWatermarkTable =>
    _lwm
    
  fun ref _translate_get(): TranslationTable =>
    _translate
  
  fun ref _origins_get(): OriginSet =>
    _origins

  be update_watermark(route_id: U64, seq_id: U64)
  =>
    """
    Process a high watermark received from a downstream step.
    TODO: receive watermark, flush buffers and send another watermark
    """
    _update_watermark(route_id, seq_id)
  
  fun _send_watermark() =>
    // for origin in _all_origins.values do
    //   origin.update_watermark(route_id, seq_id)
    // end
    None
    
  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) 
  =>
    match _runner
    | let r: ReplayableRunner =>
      r.replay_log_entry(uid, frac_ids, statechange_id, payload, this)
    end

  be replay_finished() =>
    match _runner
    | let r: ReplayableRunner =>
      r.replay_finished()
    end

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

  //////////////
  // CREDIT FLOW  
  // TODO: Add implementation
  be receive_credits(credits: USize, from: CreditFlowConsumer) =>
    None
    
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1) =>
    None

// TODO: If this sticks around after boundary work, it will have to become
// an ResilientOrigin to compile, but that seems weird so we need to
// rethink it
actor PartitionProxy is CreditFlowProducer
  let _worker_name: String
  var _router: (Router val | None) = None
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth
  var _seq_id: U64 = 0
  // TODO: This None will break when we no use None as origin possibility
  let _incoming_envelope: MsgEnvelope = MsgEnvelope(None, 0, None, 0, 0)
  let _outgoing_envelope: MsgEnvelope = MsgEnvelope(None, 0, None, 0, 0)

  new create(worker_name: String, metrics_reporter: MetricsReporter iso, 
    auth: AmbientAuth) 
  =>
    _worker_name = worker_name
    _metrics_reporter = consume metrics_reporter
    _auth = auth

  be update_router(router: Router val) =>
    _router = router

  be receive_credits(credits: USize, from: CreditFlowConsumer) => None
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1) => None

  be forward[D: Any val](metric_name: String, source_ts: U64, data: D, 
    target_step_id: U128, from_step_id: U128, msg_uid: U128, 
    frac_ids: (Array[U64] val | None), seq_id: U64, 
    route_id: U64) 
  =>
    _seq_id = _seq_id + 1

    // TODO: This None will break when we no use None as origin possibility
    _incoming_envelope.update(None, msg_uid, frac_ids, seq_id, route_id)
    _outgoing_envelope.update(None, msg_uid, frac_ids, _seq_id)

    let is_finished = 
      try
        let return_proxy_address = ProxyAddress(_worker_name, from_step_id)

        // TODO: This forward_msg should be created in a router, which is
        // the thing normally responsible for creating the outgoing 
        // envelope arguments
        let forward_msg = ChannelMsgEncoder.data_channel[D](target_step_id, 
          0, _worker_name, source_ts, data, metric_name, _auth,
          return_proxy_address, msg_uid, frac_ids, seq_id,
          // TODO: Generate correct route id 
          0)

        match _router
        | let r: Router val =>
          r.route[Array[ByteSeq] val](metric_name, source_ts, 
            forward_msg, _incoming_envelope, _outgoing_envelope,
            this)
          false
        else
          @printf[I32]("PartitionProxy has no router\n".cstring())
          true
        end
      else
        @printf[I32]("Problem encoding forwarded message\n".cstring())
        true
      end

    if is_finished then
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

type StepInitializer is (StepBuilder | PartitionedPreStateStepBuilder)

class StepBuilder
  let _runner_builder: RunnerBuilder val
  let _id: U128
  let _is_stateful: Bool

  new val create(r: RunnerBuilder val, id': U128,
    is_stateful': Bool = false) 
  =>    
    _runner_builder = r
    _id = id'
    _is_stateful = is_stateful'

  fun name(): String => _runner_builder.name()
  fun id(): U128 => _id
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String, alfred: Alfred, router: Router val = EmptyRouter): 
      Step tag 
  =>
    let runner = _runner_builder(MetricsReporter(pipeline_name, 
      metrics_conn) where alfred = alfred, router = router)
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn), router)
    step.update_router(next)
    step

class PartitionedPreStateStepBuilder
  let _pre_state_subpartition: PreStateSubpartition val
  let _runner_builder: RunnerBuilder val
  let _state_name: String

  new val create(sub: PreStateSubpartition val, r: RunnerBuilder val, 
    state_name': String) 
  =>
    _pre_state_subpartition = sub
    _runner_builder = r
    _state_name = state_name'

  fun name(): String => _runner_builder.name() + " partition"
  fun state_name(): String => _state_name
  fun id(): U128 => 0
  fun is_stateful(): Bool => true
  fun is_partitioned(): Bool => true
  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String, alfred: Alfred, router: Router val = EmptyRouter): 
      Step tag 
  =>
    Step(RouterRunner, MetricsReporter(pipeline_name, metrics_conn))

  fun build_partition(worker_name: String, state_addresses: StateAddresses val,
    metrics_conn: TCPConnection, auth: AmbientAuth, connections: Connections, 
    alfred: Alfred, state_comp_router: Router val = EmptyRouter): 
      PartitionRouter val 
  =>
    _pre_state_subpartition.build(worker_name, _runner_builder, 
      state_addresses, metrics_conn, auth, connections, alfred,
      state_comp_router)
