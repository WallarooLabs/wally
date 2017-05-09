use "sendence/options"

class StartupOptions
  var m_arg: (Array[String] | None) = None
  var i_addrs_write: Array[Array[String]] trn =
    recover Array[Array[String]] end
  var o_arg: (Array[String] | None) = None
  var c_arg: (Array[String] | None) = None
  var d_arg: (Array[String] | None) = None
  var my_c_addr: Array[String] = ["", "0"]
  var my_d_addr: Array[String] = ["", "0"]
  var p_arg: (Array[String] | None) = None
  var worker_count: USize = 1
  var is_initializer: Bool = false
  var worker_name: String = ""
  var resilience_dir: String = "/tmp"
  var event_log_file_length: (USize | None) = None
  var j_arg: (Array[String] | None) = None
  var is_joining: Bool = false
  var is_swarm_managed: Bool = false
  var a_arg: (String | None) = None
  var stop_the_world_pause: U64 = 2_000_000_000

primitive WallarooConfig
  fun application_args(args: Array[String] val): Array[String] val ? =>
    (let z, let remaining) = _parse(args)
    remaining

  fun wallaroo_args(args: Array[String] val): StartupOptions ? =>
    (let so, let z) = _parse(args)
    so

  fun _parse(args: Array[String] val): (StartupOptions, Array[String] val) ? =>
    let so: StartupOptions ref = StartupOptions

    var options = Options(args, false)

    options
      .add("metrics", "m", StringArgument)
      .add("in", "i", StringArgument)
      .add("out", "o", StringArgument)
      .add("control", "c", StringArgument)
      .add("data", "d", StringArgument)
      .add("my-control", "x", StringArgument)
      .add("my-data", "y", StringArgument)
      .add("phone-home", "p", StringArgument)
      .add("file", "f", StringArgument)
      // worker count includes the initial "leader" since there is no
      // persisting leader
      .add("worker-count", "w", I64Argument)
      .add("topology-initializer", "t", None)
      .add("name", "n", StringArgument)
      .add("resilience-dir", "r", StringArgument)
      .add("event_log-file-length", "l", I64Argument)
      // pass in control address of any worker as the value of this parameter
      // to join a running cluster
      // TODO: Actually make a joining worker a first class citizen.
      // All this does is give the new worker metrics info so it can
      // register with the UI (a "nominal join").
      .add("join", "j", StringArgument)
      .add("swarm-managed", "s", None)
      .add("swarm-manager-address", "a", StringArgument)
      .add("stop-pause", "u", I64Argument)

    for option in options do
      match option
      | ("metrics", let arg: String) => so.m_arg = arg.split(":")
      | ("in", let arg: String) =>
        for addr in arg.split(",").values() do
          so.i_addrs_write.push(addr.split(":"))
        end
      | ("out", let arg: String) => so.o_arg = arg.split(":")
      | ("control", let arg: String) => so.c_arg = arg.split(":")
      | ("data", let arg: String) => so.d_arg = arg.split(":")
      | ("my-control", let arg: String) => so.my_c_addr = arg.split(":")
      | ("my-data", let arg: String) => so.my_d_addr = arg.split(":")
      | ("phone-home", let arg: String) => so.p_arg = arg.split(":")
      | ("worker-count", let arg: I64) =>
        so.worker_count = arg.usize()
      | ("topology-initializer", None) => so.is_initializer = true
      | ("name", let arg: String) => so.worker_name = arg
      | ("resilience-dir", let arg: String) =>
        if arg.substring(arg.size().isize() - 1) == "/" then
          @printf[I32]("--resilience-dir must not end in /\n".cstring())
          error
        else
          so.resilience_dir = arg
        end
      | ("event_log-file-length", let arg: I64) =>
        so.event_log_file_length = arg.usize()
      | ("join", let arg: String) =>
        so.j_arg = arg.split(":")
        so.is_joining = true
      | ("swarm-managed", None) => so.is_swarm_managed = true
      | ("swarm-manager-address", let arg: String) => so.a_arg = arg
      | ("stop-pause", let arg: I64) =>
        so.stop_the_world_pause = arg.u64()
      end
    end

    var o = Options(options.remaining(), false)


    (so, options.remaining())
