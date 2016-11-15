use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/tcp-source"
use "wallaroo/tcp-sink"

type StepInitializer is (StepBuilder | PartitionedPreStateStepBuilder | 
  SourceData | EgressBuilder)

class StepBuilder
  let _app_name: String
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder val
  let _id: U128
  let _pre_state_target_id: (U128 | None)
  let _is_stateful: Bool
  let _forward_route_builder: RouteBuilder val

  new val create(app_name: String, pipeline_name': String, 
    r: RunnerBuilder val, id': U128, is_stateful': Bool = false, 
    pre_state_target_id': (U128 | None) = None,
    forward_route_builder': RouteBuilder val = EmptyRouteBuilder) 
  =>    
    _app_name = app_name
    _pipeline_name = pipeline_name'
    _runner_builder = r
    _id = id'
    _is_stateful = is_stateful'
    _pre_state_target_id = pre_state_target_id'
    _forward_route_builder = forward_route_builder'

  fun name(): String => _runner_builder.name()
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => _pre_state_target_id
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder

  fun apply(next: Router val, metrics_conn: TCPConnection, alfred: Alfred, 
    router: Router val = EmptyRouter, 
    default_target: (Step | None) = None): Step tag 
  =>
    let runner = _runner_builder(MetricsReporter(_app_name, 
      metrics_conn) where alfred = alfred, router = router)
    let step = Step(consume runner, 
      MetricsReporter(_app_name, metrics_conn), _id,
      _runner_builder.route_builder(), alfred, router, default_target)
    step.update_router(next)
    step

class PartitionedPreStateStepBuilder
  let _app_name: String
  let _pipeline_name: String
  let _pre_state_subpartition: PreStateSubpartition val
  let _runner_builder: RunnerBuilder val
  let _state_name: String
  let _id: U128
  let _pre_state_target_id: U128
  let _forward_route_builder: RouteBuilder val
  let _default_target_name: String

  new val create(app_name: String, pipeline_name': String, 
    sub: PreStateSubpartition val, r: RunnerBuilder val, state_name': String,
    pre_state_target_id': U128, forward_route_builder': RouteBuilder val,
    default_target_name': String = "") 
  =>
    _app_name = app_name
    _pipeline_name = pipeline_name'
    _pre_state_subpartition = sub
    _runner_builder = r
    _state_name = state_name'
    _id = _runner_builder.id()
    _pre_state_target_id = pre_state_target_id'
    _forward_route_builder = forward_route_builder'
    _default_target_name = default_target_name'

  fun name(): String => _runner_builder.name() + " partition"
  fun pipeline_name(): String => _pipeline_name
  fun state_name(): String => _state_name
  fun id(): U128 => _id
  fun pre_state_target_id(): U128 => _pre_state_target_id
  fun is_stateful(): Bool => true
  fun is_partitioned(): Bool => true
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun default_target_name(): String => _default_target_name
    
  fun apply(next: Router val, metrics_conn: TCPConnection, alfred: Alfred, 
    router: Router val = EmptyRouter): Step tag 
  =>
    Step(RouterRunner, MetricsReporter(_app_name, metrics_conn), _id,
      _runner_builder.route_builder(), alfred)

  fun build_partition(worker_name: String, state_addresses: StateAddresses val,
    metrics_conn: TCPConnection, auth: AmbientAuth, connections: Connections, 
    alfred: Alfred, 
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    state_comp_router: Router val = EmptyRouter,
    default_router: (Router val | None) = None): 
      PartitionRouter val 
  =>
    _pre_state_subpartition.build(_app_name, worker_name, _runner_builder, 
      state_addresses, metrics_conn, auth, connections, alfred,
      outgoing_boundaries, state_comp_router, default_router)

class SourceData
  let _id: U128
  let _pipeline_name: String
  let _name: String
  let _builder: SourceBuilderBuilder val
  let _runner_builder: RunnerBuilder val
  let _route_builder: RouteBuilder val
  let _address: Array[String] val
  let _pre_state_target_id: (U128 | None)

  new val create(id': U128, b: SourceBuilderBuilder val, r: RunnerBuilder val,
    default_source_route_builder: RouteBuilder val,
    a: Array[String] val, pre_state_target_id': (U128 | None) = None) 
  =>
    _id = id'
    _pipeline_name = b.name()
    _name = "| " + _pipeline_name + " source | " + r.name() + "|"
    _builder = b
    _runner_builder = r
    _route_builder = 
      match _runner_builder.route_builder()
      | let e: EmptyRouteBuilder val =>
        default_source_route_builder
      else
        _runner_builder.route_builder()
      end
    _address = a
    _pre_state_target_id = pre_state_target_id'

  fun builder(): SourceBuilderBuilder val => _builder
  fun runner_builder(): RunnerBuilder val => _runner_builder
  fun route_builder(): RouteBuilder val => _route_builder
  fun address(): Array[String] val => _address

  fun name(): String => _name
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => _pre_state_target_id
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

class EgressBuilder
  let _name: String
  let _pipeline_name: String
  let _id: U128
  let _addr: (Array[String] val | ProxyAddress val)
  let _sink_builder: (TCPSinkBuilder val | None)

  new val create(pipeline_name': String, id': U128,
    addr: (Array[String] val | ProxyAddress val), 
    sink_builder: (TCPSinkBuilder val | None) = None)
  =>
    _pipeline_name = pipeline_name'
    _name = 
      match addr
      | let pa: ProxyAddress val =>
        "Proxy to " + pa.worker
      else
        _pipeline_name + " sink"
      end

    _id = id'
    _addr = addr
    _sink_builder = sink_builder

  fun name(): String => _name
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => None
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

  fun target_address(): (Array[String] val | ProxyAddress val | 
    PartitionAddresses val) => _addr

  fun apply(worker_name: String, reporter: MetricsReporter iso, 
    auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val = 
      recover Map[String, OutgoingBoundary] end): CreditFlowConsumerStep tag ?
  =>    
    match _addr
    | let a: Array[String] val =>
      try
        match _sink_builder
        | let tsb: TCPSinkBuilder val =>
          @printf[I32](("Connecting to sink at " + a(0) + ":" + a(1) + "\n").cstring())

          tsb(reporter.clone(), a(0), a(1))
        else
          EmptySink
        end
      else
        @printf[I32]("Error connecting to sink.\n".cstring())
        error
      end
    | let p: ProxyAddress val =>
      try
        proxies(p.worker)
      else
        @printf[I32](("Couldn't find proxy for " + p.worker + ".\n").cstring())
        error
      end
    else
      // The match is exhaustive, so this can't happen
      @printf[I32]("Exhaustive match failed somehow\n".cstring())
      error
    end 
