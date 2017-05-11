use "buffered"
use "collections"
use "files"
use "serialise"
use "time"
use "sendence/bytes"
use "sendence/rand"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor WActorInitializer
  let _app_name: String
  var _system: (LocalActorSystem | None) = None
  let _auth: AmbientAuth
  let _workers: Array[String] val
  let _event_log: EventLog
  let _local_actor_system_file: String
  let _input_addrs: Array[Array[String]] val
  let _recovery: Recovery
  var _central_registry: (CentralWActorRegistry | None) = None

  ////////////////
  // Placeholders
  ////////////////
  let _empty_connections: Connections
  let _empty_router_registry: RouterRegistry

  ////////////////
  // Demo fields
  ////////////////
  let _expected_iterations: USize
  var _iteration: USize = 0
  var _serialized: Array[U8] iso = recover Array[U8] end
  var _received_serialized: USize = 0
  let _actor_count: USize
  let _actors: Array[WActorWrapper tag] = _actors.create()
  let _rand: Rand

  new create(app_name: String, s: LocalActorSystem, auth: AmbientAuth,
    event_log: EventLog, input_addrs: Array[Array[String]] val,
    local_actor_system_file: String, actor_count: USize,
    expected_iterations: USize, recovery: Recovery, workers: Array[String] val,
    seed: U64, empty_connections: Connections,
    empty_router_registry: RouterRegistry)
  =>
    _app_name = app_name
    _system = s
    _auth = auth
    _workers = workers
    _event_log = event_log
    _local_actor_system_file = local_actor_system_file
    _input_addrs = input_addrs
    _expected_iterations = expected_iterations
    _actor_count = actor_count
    _recovery = recovery
    _rand = Rand(seed)
    _empty_connections = empty_connections
    _empty_router_registry = empty_router_registry
    _central_registry = CentralWActorRegistry(_auth, this, _event_log,
      _rand.u64())

  fun ref _save_local_topology() =>
    @printf[I32]("||| -- Saving Actor System! -- |||\n".cstring())
    match _system
    | let las: LocalActorSystem =>
      try
        let local_actor_system_file = FilePath(_auth, _local_actor_system_file)
        // TODO: Back up old file before clearing it?
        let file = File(local_actor_system_file)
        // Clear contents of file.
        file.set_length(0)
        let wb = Writer
        let serialised_actor_system: Array[U8] val =
          Serialised(SerialiseAuth(_auth), las).output(
            OutputSerialisedAuth(_auth))
        wb.write(serialised_actor_system)
        file.writev(recover val wb.done() end)
        file.sync()
        file.dispose()
      else
        @printf[I32]("Error saving actor system!\n".cstring())
        Fail()
      end
    else
      @printf[I32]("Error saving actor system!\n".cstring())
      Fail()
    end

  be initialize(is_recovering: Bool) =>
    try
      ifdef "resilience" then
        let local_actor_system_file = FilePath(_auth, _local_actor_system_file)
        if local_actor_system_file.exists() then
          //we are recovering an existing worker topology
          let data = recover val
            let file = File(local_actor_system_file)
            file.read(file.size())
          end
          match Serialised.input(InputSerialisedAuth(_auth), data)(
            DeserialiseAuth(_auth))
          | let las: LocalActorSystem =>
            _system = las
            @printf[I32]("||| -- Recovered Actor System! -- |||\n".cstring())
          else
            @printf[I32]("error restoring previous actor system!".cstring())
          end
        end
      end

      ifdef "resilience" then
        _save_local_topology()
      end

      match _system
      | let las: LocalActorSystem =>
        match _central_registry
        | let cr: CentralWActorRegistry =>
          try
            for (idx, source) in las.sources().pairs() do
              let source_notify = WActorSourceNotify(_auth,
                source._1, source._2, cr, _event_log)

              let source_builder = ActorSystemSourceBuilder(_app_name,
                source._1, source._2, cr)

              let empty_metrics_reporter =
                MetricsReporter(_app_name, "", MetricsSink("", "", "", ""))

              let source_addr = _input_addrs(idx)
              let host = source_addr(0)
              let service = source_addr(1)

              TCPSourceListener(source_builder,
                EmptyRouter, _empty_router_registry, EmptyRouteBuilder,
                recover Map[String, OutgoingBoundaryBuilder val] end,
                recover Array[TCPSink] end, _event_log, _auth,
                this, consume empty_metrics_reporter where host = host,
                service = service)
            end
          else
            @printf[I32]("Error creating sources! Be sure you've provided as many source addresses as you have defined sources.\n".cstring())
            Fail()
          end

          for builder in las.actor_builders().values() do
            _actors.push(builder(cr, _auth, _event_log, _rand.u64()))
          end
        else
          Fail()
        end
      else
        Fail()
      end

      if is_recovering then
        _recovery.start_recovery(this, _workers)
      else
        kick_off_demo()
      end
    else
      Fail()
    end

  be kick_off_demo() =>
    @printf[I32]("\n#########################\n".cstring())
    @printf[I32]("#*# Kicking off demo! #*#\n".cstring())
    @printf[I32]("#########################\n".cstring())
    let timers = Timers
    let t = Timer(MainNotify(this, _expected_iterations), 1_000_000_000)
    timers(consume t)

  be add_actor(b: WActorWrapperBuilder) =>
    match _system
    | let las: LocalActorSystem =>
      _system = las.add_actor(b)
    end

  be act() =>
    for w_actor in _actors.values() do
      w_actor.process(Act)
      w_actor.pickle(this)
    end
    _iteration = _iteration + 1

  be finish() =>
    for w_actor in _actors.values() do
      w_actor.process(Finish)
    end

  be add_serialized(ser: ByteSeq val) =>
    match ser
    | let s: String =>
      for byte in s.values() do
        _serialized.push(byte)
      end
    | let arr: Array[U8] val =>
      for byte in arr.values() do
        _serialized.push(byte)
      end
    end
    _received_serialized = _received_serialized + 1
    if _received_serialized == _actor_count then
      // TODO: Remove when not needed for DEMO
      // let last = (_serialized = recover Array[U8] end)
      // let digest = Pickle.md5_digest(String.from_iso_array(consume last))
      // @printf[I32]("Digest for iteration %lu: %s\n".cstring(), _iteration,
      //   digest.cstring())
      _received_serialized = 0
      if _iteration < _expected_iterations then
        act()
      else
        finish()
      end
    end

class val ActorSystemSourceBuilder is SourceBuilder
  let _app_name: String
  let _handler: WActorFramedSourceHandler
  let _actor_router: WActorRouter
  let _central_actor_registry: CentralWActorRegistry

  new val create(app_name: String, handler: WActorFramedSourceHandler,
    actor_router: WActorRouter, central_actor_registry: CentralWActorRegistry)
  =>
    _app_name = app_name
    _handler = handler
    _actor_router = actor_router
    _central_actor_registry = central_actor_registry

  fun name(): String =>
    _app_name + " source"

  fun apply(event_log: EventLog, auth: AmbientAuth, target_router: Router val):
    TCPSourceNotify iso^
  =>
    WActorSourceNotify(auth, _handler, _actor_router,
      _central_actor_registry, event_log)

  fun val update_router(router: Router val): SourceBuilder =>
    this

class MainNotify is TimerNotify
  let _main: WActorInitializer
  let _n: USize

  new iso create(main: WActorInitializer, n: USize) =>
    _main = main
    _n = n

  fun ref apply(timer: Timer, count: U64): Bool =>
    // If we need to simulate the DCM Toy Model for some
    // reason in future demo runs, we still want this.
    // TODO: Remove this comment and associated code in this file.
    // _main.act()
    false
