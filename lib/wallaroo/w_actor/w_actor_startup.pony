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
  var _worker_name: String = "unnamed"
  var _resilience_dir: String = "/tmp"
  var _swarm_manager_addr: String = ""
  var _event_log_file: String = ""
  var _local_actor_system_file: String = ""
  var _event_log_file_length: (USize | None) = None
  // DEMO fields
  var _iterations: USize = 100

  // TODO: remove DEMO param actor_count
  new create(env: Env, system: ActorSystem val, app_name: (String | None),
    actor_count: USize)
  =>
    @printf[I32]("#########################################\n".cstring())
    @printf[I32]("#*# Wallaroo Actor System Application #*#\n".cstring())
    @printf[I32]("#########################################\n\n".cstring())
    @printf[I32]("#*# %s starting up! #*#\n\n".cstring(),
      _worker_name.cstring())

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
        // DEMO params
        .add("iterations", "i", I64Argument)

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
        // DEMO params
        | ("iterations", let arg: I64) => _iterations = arg.usize()
        end
      end

      // Currently only support one worker
      _worker_count = 1

      let name = match _app_name
        | let n: String => n
        else
          ""
        end

      //////////////////
      // RESILIENCE
      //////////////////
      _event_log_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".evlog"
      _local_actor_system_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".local-actor-system"

      ifdef "resilience" then
        @printf[I32](("||| Resilience directory: " + _resilience_dir +
          " |||\n").cstring())
      end

      var is_recovering: Bool = false

      // check to see if we can recover
      ifdef "resilience" then
        // Use Set to make the logic explicit and clear
        let existing_files: Set[String] = Set[String]

        let event_log_filepath: FilePath = FilePath(auth, _event_log_file)
        if event_log_filepath.exists() then
          existing_files.set(event_log_filepath.path)
        end

        let local_actor_system_filepath: FilePath = FilePath(auth,
          _local_actor_system_file)
        if local_actor_system_filepath.exists() then
          existing_files.set(local_actor_system_filepath.path)
        end

        let required_files: Set[String] = Set[String]
        required_files.set(event_log_filepath.path)
        required_files.set(local_actor_system_filepath.path)

        // Only validate _all_ files exist if _any_ files exist.
        if existing_files.size() > 0 then
          // If any recovery file exists, but not all, then fail
          if (required_files.op_and(existing_files)) != required_files then
            @printf[I32](("Some resilience recovery files are missing! "
              + "Cannot continue!\n").cstring())
              let files_missing = required_files.without(existing_files)
              let files_missing_str: String val = "\n    ".join(
                Iter[String](files_missing.values()).collect(Array[String]))
              @printf[I32]("The missing files are:\n    %s\n".cstring(),
                files_missing_str.cstring())
            Fail()
          else
            @printf[I32]("||| Recovering from recovery files! |||\n".cstring())
            // we are recovering because all files exist
            is_recovering = true
          end
        end
      end

      //////////////////////////
      // Actor System Startup
      //////////////////////////
      let event_log = ifdef "resilience" then
          EventLog(_env, _event_log_file
            where backend_file_length = _event_log_file_length,
              logging_batch_size = 1)
        else
          EventLog(_env, None)
        end

      let recovery = Recovery(_worker_name, event_log)

      let seed: U64 = 123456

      let local_system = LocalActorSystem(_system.name(),
        _system.actor_builders())
      let initializer = WActorInitializer(local_system, auth, event_log,
        _local_actor_system_file, actor_count, _iterations, recovery,
        recover [_worker_name] end, seed)
      initializer.initialize(is_recovering)
    else
      Fail()
    end
