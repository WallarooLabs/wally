use "collections"
use "net"
use "sendence/guid"
use "wallaroo/backpressure"
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

interface PartitionFindable
  fun find_partition(finder: PartitionFinder val): Router val

interface PartitionFinder
  fun find[D: Any val](data: D): Router val

class StatelessPartitionFinder[In: Any val, Key: (Hashable val & Equatable[Key] val)]
  let _partition_function: PartitionFunction[In, Key] val
  let _partitions: Map[Key, Router val] = Map[Key, Router val]

  new val create(pf: PartitionFunction[In, Key] val, keys: Array[Key] val,
    router_builder: RouterBuilder val)
  =>
    _partition_function = pf
    for key in keys.values() do
      _partitions(key) = router_builder()
    end

  fun find[D: Any val](data: D): Router val =>
    try
      match data
      | let input: In =>
        _partitions(_partition_function(input))
      else
        EmptyRouter
      end
    else
      EmptyRouter
    end

class StatePartitionFinder[In: Any val, Key: (Hashable val & Equatable[Key] val)]
  let _partition_function: PartitionFunction[In, Key] val
  let _partitions: Map[Key, Router val] = Map[Key, Router val]

  new val create(pf: PartitionFunction[In, Key] val, keys: Array[Key] val,
    router_builder: RouterBuilder val)
  =>
    _partition_function = pf
    for key in keys.values() do
      _partitions(key) = router_builder()
    end

  fun find[D: Any val](data: D): Router val =>
    try
      match data
      | let input: In =>
        _partitions(_partition_function(input))
      else
        EmptyRouter
      end
    else
      EmptyRouter
    end


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

// class PartitionRouterBuilder
//   fun build(state_addresses: StateAddresses val, metrics_conn: TCPConnection,
//     state_comp_router: Router val = EmptyRouter): Router val


trait PreStateSubpartition
  fun build(app_name: String, worker_name: String, 
    runner_builder: RunnerBuilder val,
    state_addresses: StateAddresses val, metrics_conn: TCPConnection,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
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
    pipeline_name': String, multi_worker: Bool = false)
  =>
    _partition_addresses = partition_addresses'
    _id_map = id_map'
    _partition_function = partition_function'
    _pipeline_name = pipeline_name'

  fun build(app_name: String, worker_name: String,
    runner_builder: RunnerBuilder val,
    state_addresses: StateAddresses val, metrics_conn: TCPConnection,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
    state_comp_router: Router val = EmptyRouter):
    LocalPartitionRouter[PIn, Key] val
  =>
    // map from worker name to partition proxy
    let partition_proxies_trn: Map[String, PartitionProxy] trn =
      recover Map[String, PartitionProxy] end

    for (k, proxy_address) in _partition_addresses.pairs() do
      // create partition proxies
      if (not partition_proxies_trn.contains(proxy_address.worker)) and
        (proxy_address.worker != worker_name) then
        @printf[I32](("Adding partition proxy to " + proxy_address.worker + "for " + _pipeline_name + " pipeline\n").cstring())
        partition_proxies_trn(proxy_address.worker) = PartitionProxy(
          proxy_address.worker, MetricsReporter(app_name, metrics_conn),
          auth)
      end
    end
    let partition_proxies: Map[String, PartitionProxy] val =
      consume partition_proxies_trn
    // connections.register_partition_proxies(partition_proxies)

    let routes: Map[Key, (Step | PartitionProxy)] trn =
      recover Map[Key, (Step | PartitionProxy)] end

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
            routes(key) = partition_proxies(pa.worker)
          else
            @printf[I32](("Missing PartitionProxy for " + pa.worker + "!\n").cstring())
          end
        end
      else
        @printf[I32]("Missing proxy address!\n".cstring())
      end
    end

    @printf[I32](("Spinning up " + partition_count.string() + " prestate partitions for " + _pipeline_name + " pipeline\n").cstring())

    LocalPartitionRouter[PIn, Key](consume m, _id_map, consume routes,
      _partition_function)
