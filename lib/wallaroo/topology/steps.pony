use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"

// trait RunnableStep
//   be update_router(router: Router val)
//   be run[D: Any val](metric_name: String, source_ts: U64, data: D)
//   be dispose()

trait RunnableStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D)

actor Step is (RunnableStep & CreditFlowProducer)
  let _runner: Runner
  var _router: Router val
  let _metrics_reporter: MetricsReporter 

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso,
    router: Router val = EmptyRouter) =>
    _runner = consume runner
    _metrics_reporter = consume metrics_reporter
    _router = router

  be update_router(router: Router val) =>
    _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D) =>
    let is_finished = _runner.run[D](metric_name, source_ts, data, this,
      _router)

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

  // Credit Flow  
  // TODO: Add implementation
  be receive_credits(credits: USize, from: CreditFlowConsumer) =>
    None
    
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1) =>
    None

actor PartitionProxy is CreditFlowProducer
  let _worker_name: String
  var _router: (Router val | None) = None
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth

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
    target_step_id: U128) 
  =>
    let is_finished = 
      try
        let forward_msg = ChannelMsgEncoder.data_channel[D](target_step_id, 
          0, _worker_name, source_ts, data, metric_name, _auth)
        match _router
        | let r: Router val =>
          r.route[Array[ByteSeq] val](metric_name, source_ts, 
            forward_msg, this)
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
    pipeline_name: String, router: Router val = EmptyRouter): Step tag =>
    let runner = _runner_builder(MetricsReporter(pipeline_name, 
      metrics_conn) where router = router)
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
    pipeline_name: String, router: Router val = EmptyRouter): Step tag =>
    Step(RouterRunner, MetricsReporter(pipeline_name, metrics_conn))

  fun build_partition(worker_name: String, state_addresses: StateAddresses val,
    metrics_conn: TCPConnection, auth: AmbientAuth, connections: Connections, 
    state_comp_router: Router val = EmptyRouter): PartitionRouter val 
  =>
    _pre_state_subpartition.build(worker_name, _runner_builder, 
      state_addresses, metrics_conn, auth, connections, state_comp_router)
