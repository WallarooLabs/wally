use "buffered"
use "collections"
use "files"
use "itertools"
use "net"
use "net/http"
use "options"
use "time"
use "sendence/hub"
use "sendence/rand"
use "wallaroo/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/recovery"
use "wallaroo/topology"

actor ActorSystemStartup
  let _env: Env
  let _system: ActorSystem val
  let _app_name: (String | None)
  var _worker_count: USize = 1
  var _is_initializer: Bool = false
  var _is_multi_worker: Bool = true
  var _is_joining: Bool = false
  var _is_swarm_managed: Bool = false
  var _worker_name: String = ""
  var _resilience_dir: String = "/tmp"
  var _swarm_manager_addr: String = ""
  var _event_log_file: String = ""
  var _actor_system_file: String = ""
  var _event_log: (EventLog | None) = None
  var _event_log_file_length: (USize | None) = None
//   var _joining_listener: (TCPListener | None) = None

  ////////////////
  // Demo fields
  ////////////////
  let _expected_iterations: USize
  var _iteration: USize = 0
  var _serialized: Array[U8] iso = recover Array[U8] end
  var _received_serialized: USize = 0
  let _actor_count: USize
  let _central_registry: CentralWActorRegistry = CentralWActorRegistry
  let _actors: Array[WActorWrapper tag] = _actors.create()

  new create(env: Env, system: ActorSystem val, app_name: (String | None)) =>
    _env = env
    _system = system
    _app_name = app_name
    ifdef "resilience" then
      @printf[I32]("****RESILIENCE is active****\n".cstring())
    end
    ifdef "trace" then
      @printf[I32]("****TRACE is active****\n".cstring())
    end

    try
      var options = Options(_env.args, false)
      let auth = _env.root as AmbientAuth

      options
        // worker count includes the initial "leader" since there is no
        // persisting leader
        .add("worker-count", "w", I64Argument)
        .add("topology-initializer", "t", None)
        .add("name", "n", StringArgument)
        .add("resilience-dir", "r", StringArgument)
        .add("event-log-file-length", "l", I64Argument)
        // pass in control address of any worker as the value of this parameter
        // to join a running cluster
        // TODO: Actually make a joining worker a first class citizen.
        // All this does is give the new worker metrics info so it can
        // register with the UI (a "nominal join").
        .add("join", "j", StringArgument)
        .add("swarm-managed", "s", None)
        .add("swarm-manager-address", "a", StringArgument)

      for option in options do
        match option
        | ("worker-count", let arg: I64) => _worker_count = arg.usize()
        | ("topology-initializer", None) => _is_initializer = true
        | ("name", let arg: String) => _worker_name = arg
        | ("resilience-dir", let arg: String) =>
          if arg.substring(arg.size().isize() - 1) == "/" then
            @printf[I32]("--resilience-dir must not end in /\n".cstring())
            error
          else
            _resilience_dir = arg
          end
        | ("event-log-file-length", let arg: I64) =>
          _event_log_file_length = arg.usize()
        end
      end
    end

    // Currently only support one worker
    _worker_count = 1

    //////////////////
    // DEMO SETUP
    //////////////////
    let seed: U64 = 123456
    _actor_count = 10
    _expected_iterations = 100
    @printf[I32]("WActor Test\n".cstring())
    initialize(seed, env)

  fun ref initialize(seed: U64, env: Env) =>
    try
      let rand = Rand(seed)
      let auth = env.root as AmbientAuth
      for builder in _system.actor_builders().values() do
        _actors.push(builder(_central_registry, auth, rand.u64()))
      end
      let timers = Timers
      let t = Timer(MainNotify(this, _expected_iterations), 1_000_000_000)
      timers(consume t)
    else
      Fail()
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

  be add_serialized(ser: Array[U8] val) =>
    for byte in ser.values() do
      _serialized.push(byte)
    end
    _received_serialized = _received_serialized + 1
    if _received_serialized == _actor_count then
      let last = (_serialized = recover Array[U8] end)
      let digest = Pickle.md5_digest(String.from_iso_array(consume last))
      @printf[I32]("Digest for iteration %lu: %s\n".cstring(), _iteration,
        digest.cstring())
      _received_serialized = 0
      if _iteration < _expected_iterations then
        act()
      else
        finish()
      end
    end

class MainNotify is TimerNotify
  let _main: ActorSystemStartup
  let _n: USize

  new iso create(main: ActorSystemStartup, n: USize) =>
    _main = main
    _n = n

  fun ref apply(timer: Timer, count: U64): Bool =>
    _main.act()
    false


