use "collections"
use "net"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"

class Partition[In: Any val, Key: (Hashable val & Equatable[Key])]
  let _function: PartitionFunction[In, Key] val
  let _keys: Array[Key] val

  new val create(f: PartitionFunction[In, Key] val, ks: Array[Key] val) =>
    _function = f
    _keys = ks

  fun function(): PartitionFunction[In, Key] val => _function
  fun keys(): Array[Key] val => _keys

interface PartitionFunction[In: Any val, Key: (Hashable val & Equatable[Key] val)]
  fun apply(input: In): Key

primitive SingleStepPartitionFunction[In: Any val] is 
  PartitionFunction[In, U8]
  fun apply(input: In): U8 => 0

interface PartitionAddresses
  fun apply(key: Any val): (ProxyAddress val | None)

class KeyedPartitionAddresses[Key: (Hashable val & Equatable[Key] val)]
  let _addresses: Map[Key, ProxyAddress val] val

  new val create(a: Map[Key, ProxyAddress val] val) =>
    _addresses = a

  fun apply(k: Any val): (ProxyAddress val | None) =>
    match k
    | let key: Key =>
      try
        _addresses(key)
      else
        None
      end
    else
      None
    end

  fun pairs(): Iterator[(Key, ProxyAddress val)] => _addresses.pairs()

interface StateAddresses
  fun apply(key: Any val): (Step | None)
  fun register_routes(router: Router val, route_builder: RouteBuilder val)

class KeyedStateAddresses[Key: (Hashable val & Equatable[Key] val)]
  let _addresses: Map[Key, Step] val

  new val create(a: Map[Key, Step] val) =>
    _addresses = a

  fun apply(k: Any val): (Step | None) =>
    match k
    | let key: Key =>
      try
        _addresses(key)
      else
        None
      end
    else
      None
    end

  fun register_routes(router: Router val, route_builder: RouteBuilder val) =>
    for step in _addresses.values() do
      step.register_routes(router, route_builder)
    end

trait StateSubpartition
  fun build(app_name: String, metrics_conn: TCPConnection, alfred: Alfred): 
    StateAddresses val

class KeyedStateSubpartition[Key: (Hashable val & Equatable[Key] val)] is
  StateSubpartition
  let _keys: Array[Key] val
  let _runner_builder: RunnerBuilder val

  new val create(keys: Array[Key] val, 
    runner_builder: RunnerBuilder val, multi_worker: Bool = false) 
  =>
    _keys = keys
    _runner_builder = runner_builder

  fun build(app_name: String, metrics_conn: TCPConnection, alfred: Alfred): 
    StateAddresses val 
  =>
    let m: Map[Key, Step] trn = recover Map[Key, Step] end
    let guid_gen = GuidGenerator
    for key in _keys.values() do
      let reporter = MetricsReporter(app_name, metrics_conn)
      m(key) = Step(_runner_builder(reporter.clone() where alfred = alfred),
        consume reporter, guid_gen.u128(), _runner_builder.route_builder(), alfred)
    end
    KeyedStateAddresses[Key](consume m)

trait PreStateSubpartition
  fun build(app_name: String, worker_name: String, 
    runner_builder: RunnerBuilder val,
    state_addresses: StateAddresses val, metrics_conn: TCPConnection,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    state_comp_router: Router val = EmptyRouter): PartitionRouter val

class KeyedPreStateSubpartition[PIn: Any val,
  Key: (Hashable val & Equatable[Key] val)] is PreStateSubpartition
  let _partition_addresses: KeyedPartitionAddresses[Key] val
  let _id_map: Map[Key, U128] val
  let _partition_function: PartitionFunction[PIn, Key] val
  let _pipeline_name: String

  new val create(partition_addresses': KeyedPartitionAddresses[Key] val,
    id_map': Map[Key, U128] val,
    partition_function': PartitionFunction[PIn, Key] val,
    pipeline_name': String)
  =>
    _partition_addresses = partition_addresses'
    _id_map = id_map'
    _partition_function = partition_function'
    _pipeline_name = pipeline_name'

  fun build(app_name: String, worker_name: String,
    runner_builder: RunnerBuilder val,
    state_addresses: StateAddresses val, metrics_conn: TCPConnection,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    state_comp_router: Router val = EmptyRouter):
    LocalPartitionRouter[PIn, Key] val
  =>
    let routes: Map[Key, (Step | ProxyRouter val)] trn =
      recover Map[Key, (Step | ProxyRouter val)] end

    let m: Map[U128, Step] trn = recover Map[U128, Step] end

    var partition_count: USize = 0

    for (key, id) in _id_map.pairs() do
      let proxy_address = _partition_addresses(key)
      match proxy_address
      | let pa: ProxyAddress val =>
        if pa.worker == worker_name then
          let state_step = state_addresses(key)
          match state_step
          | let s: Step =>
            // Create prestate step for this key
            let next_step = Step(runner_builder(
                MetricsReporter(app_name, metrics_conn)
                where alfred = alfred, router = state_comp_router),
              MetricsReporter(app_name, metrics_conn), id,
              runner_builder.route_builder(), alfred,
              DirectRouter(s))
            m(id) = next_step
            routes(key) = next_step
            partition_count = partition_count + 1
          else
            @printf[I32]("Subpartition: Missing state step!\n".cstring())
          end
        else
          try
            let boundary = outgoing_boundaries(pa.worker)
            routes(key) = ProxyRouter(worker_name, boundary,
              pa, auth)
          else
            @printf[I32](("Missing proxy for " + pa.worker + "!\n").cstring())
          end
        end
      else
        @printf[I32]("Missing proxy address!\n".cstring())
      end
    end

    @printf[I32](("Spinning up " + partition_count.string() + " prestate partitions for " + _pipeline_name + " pipeline\n").cstring())

    LocalPartitionRouter[PIn, Key](consume m, _id_map, consume routes,
      _partition_function)
