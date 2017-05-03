use "buffered"
use "files"
use "serialise"
use "time"
use "sendence/rand"
use "wallaroo/fail"
use "wallaroo/recovery"

actor WActorInitializer
  var _system: (LocalActorSystem | None) = None
  let _auth: AmbientAuth
  let _workers: Array[String] val
  let _event_log: EventLog
  let _local_actor_system_file: String
  let _recovery: Recovery
  var _central_registry: (CentralWActorRegistry | None) = None

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

  new create(s: LocalActorSystem, auth: AmbientAuth, event_log: EventLog,
    local_actor_system_file: String, actor_count: USize,
    expected_iterations: USize, recovery: Recovery,
    workers: Array[String] val, seed: U64)
  =>
    _system = s
    _auth = auth
    _workers = workers
    _event_log = event_log
    _local_actor_system_file = local_actor_system_file
    _expected_iterations = expected_iterations
    _actor_count = actor_count
    _recovery = recovery
    _rand = Rand(seed)
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
    ifdef "resilience" then
      try
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
      else
        @printf[I32]("error restoring previous actor system!".cstring())
      end
    end

    ifdef "resilience" then
      _save_local_topology()
    end

    match _system
    | let las: LocalActorSystem =>
      match _central_registry
      | let cr: CentralWActorRegistry =>
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

class MainNotify is TimerNotify
  let _main: WActorInitializer
  let _n: USize

  new iso create(main: WActorInitializer, n: USize) =>
    _main = main
    _n = n

  fun ref apply(timer: Timer, count: U64): Bool =>
    _main.act()
    false
