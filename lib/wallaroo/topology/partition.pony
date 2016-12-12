use "collections"
use "files"
use "net"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"

type WeightedKey[Key: (Hashable val & Equatable[Key])] is
  (Key, USize)

class Partition[In: Any val, Key: (Hashable val & Equatable[Key])]
  let _function: PartitionFunction[In, Key] val
  let _keys: (Array[WeightedKey[Key]] val | Array[Key] val)

  new val create(f: PartitionFunction[In, Key] val,
    ks: (Array[WeightedKey[Key]] val | Array[Key] val))
  =>
    _function = f
    _keys = ks

  fun function(): PartitionFunction[In, Key] val => _function
  fun keys(): (Array[WeightedKey[Key]] val | Array[Key] val) => _keys

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
  fun apply(key: Any val): (Step tag | ProxyRouter val | None)
  fun register_routes(router: Router val, route_builder: RouteBuilder val)
  fun steps(): Array[CreditFlowConsumerStep] val

class KeyedStateAddresses[Key: (Hashable val & Equatable[Key] val)]
  let _addresses: Map[Key, (Step | ProxyRouter val)] val

  new val create(a: Map[Key, (Step | ProxyRouter val)] val) =>
    _addresses = a

  fun apply(k: Any val): (Step | ProxyRouter val | None) =>
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
    for s in _addresses.values() do
      match s
      | let step: Step =>
        step.register_routes(router, route_builder)
      end
    end

  fun steps(): Array[CreditFlowConsumerStep] val =>
    let ss: Array[CreditFlowConsumerStep] trn =
      recover Array[CreditFlowConsumerStep] end
    for s in _addresses.values() do
      match s
      | let cfcs: CreditFlowConsumerStep =>
        ss.push(cfcs)
      end
    end

    consume ss

trait StateSubpartition
  fun build(app_name: String, worker_name: String,
    metrics_conn: MetricsSink,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    initializables: Array[Initializable tag],
    data_routes: Map[U128, CreditFlowConsumerStep tag],
    default_router: (Router val | None) = None): PartitionRouter val

class KeyedStateSubpartition[PIn: Any val,
  Key: (Hashable val & Equatable[Key] val)] is StateSubpartition
  let _partition_addresses: KeyedPartitionAddresses[Key] val
  let _id_map: Map[Key, U128] val
  let _partition_function: PartitionFunction[PIn, Key] val
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder val

  new val create(partition_addresses': KeyedPartitionAddresses[Key] val,
    id_map': Map[Key, U128] val, runner_builder: RunnerBuilder val,
    partition_function': PartitionFunction[PIn, Key] val,
    pipeline_name': String)
  =>
    _partition_addresses = partition_addresses'
    _id_map = id_map'
    _partition_function = partition_function'
    _pipeline_name = pipeline_name'
    _runner_builder = runner_builder

  fun build(app_name: String, worker_name: String,
    metrics_conn: MetricsSink,
    auth: AmbientAuth, connections: Connections, alfred: Alfred,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    initializables: Array[Initializable tag],
    data_routes: Map[U128, CreditFlowConsumerStep tag],
    default_router: (Router val | None) = None):
    LocalPartitionRouter[PIn, Key] val
  =>
    let guid_gen = GuidGenerator

    let routes: Map[Key, (Step | ProxyRouter val)] trn =
      recover Map[Key, (Step | ProxyRouter val)] end

    let m: Map[U128, Step] trn = recover Map[U128, Step] end

    var partition_count: USize = 0

    for (key, id) in _id_map.pairs() do
      let proxy_address = _partition_addresses(key)
      match proxy_address
      | let pa: ProxyAddress val =>
	//@printf[I32]("%s == %s ?\n".cstring(), pa.worker.cstring(), worker_name.cstring())
        if pa.worker == worker_name then
          let reporter = MetricsReporter(app_name, worker_name, metrics_conn)
          let next_state_step = Step(_runner_builder(where alfred = alfred),
            consume reporter, guid_gen.u128(), _runner_builder.route_builder(),
              alfred)

          initializables.push(next_state_step)
          data_routes(id) = next_state_step
          m(id) = next_state_step
          routes(key) = next_state_step
          partition_count = partition_count + 1
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

    @printf[I32](("Spinning up " + partition_count.string() + " state partitions for " + _pipeline_name + " pipeline\n").cstring())

    LocalPartitionRouter[PIn, Key](consume m, _id_map, consume routes,
      _partition_function, default_router)

primitive PartitionFileReader
  fun apply(filename: String, auth: AmbientAuth):
    Array[WeightedKey[String]] val
  =>
    let keys: Array[WeightedKey[String]] trn =
      recover Array[WeightedKey[String]] end

    try
      let file = File(FilePath(auth, filename))
      for line in file.lines() do
        let els = line.split(",")
        match els.size()
        | 0 => None
        | 1 => keys.push((els(0), 1))
        | 2 => keys.push((els(0), els(1).usize()))
        else
          error
        end
      end
      file.dispose()
    else
      @printf[I32]("ERROR: Problem reading partition file. Each line must have a key string and, optionally, a weight (separated by a comma)\n".cstring())
    end

    consume keys
