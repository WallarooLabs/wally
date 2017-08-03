use "sendence/options"
use "wallaroo/spike"

class StartupOptions
  var m_arg: (Array[String] | None) = None
  var input_addrs: Array[Array[String]] val = recover Array[Array[String]] end
  var output_addrs: Array[Array[String]] val = recover Array[Array[String]] end
  var c_addr: Array[String] = [""; "0"]
  var c_host: String = ""
  var c_service: String = "0"
  var d_addr: Array[String] val = recover [""; "0"] end
  var d_host: String = ""
  var d_service: String = "0"
  var my_c_addr: Array[String] = [""; "0"]
  var my_c_host: String = ""
  var my_c_service: String = "0"
  var my_d_addr: Array[String] = [""; "0"]
  var my_d_host: String = ""
  var my_d_service: String = "0"
  var p_arg: (Array[String] | None) = None
  var worker_count: USize = 1
  var is_initializer: Bool = false
  var worker_name: String = ""
  var resilience_dir: String = "/tmp"
  var event_log_file_length: (USize | None) = None
  var j_arg: (Array[String] | None) = None
  var is_joining: Bool = false
  var stop_the_world_pause: U64 = 2_000_000_000
  var spike_config: (SpikeConfig | None) = None

primitive WallarooConfig
  fun application_args(args: Array[String] val): Array[String] val ? =>
    (let z, let remaining) = _parse(args)
    remaining

  fun wallaroo_args(args: Array[String] val): StartupOptions ? =>
    (let so, let z) = _parse(args)
    so

  fun _parse(args: Array[String] val): (StartupOptions, Array[String] val) ? =>
    let so: StartupOptions ref = StartupOptions

    var spike_seed: (U64 | None) = None
    var spike_drop: Bool = false
    var spike_prob: (F64 | None) = None
    var spike_margin: (USize | None) = None

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
      .add("stop-pause", "u", I64Argument)
      .add("spike-seed", "", I64Argument)
      .add("spike-drop", "", None)
      .add("spike-prob", "", F64Argument)
      .add("spike-margin", "", I64Argument)

    for option in options do
      match option
      | ("metrics", let arg: String) => so.m_arg = arg.split(":")
      | ("in", let arg: String) =>
        let i_addrs_write: Array[Array[String]] trn =
          recover Array[Array[String]] end
        for addr in arg.split(",").values() do
          i_addrs_write.push(addr.split(":"))
        end
        so.input_addrs = consume i_addrs_write
      | ("out", let arg: String) =>
        let o_addrs_write: Array[Array[String]] trn =
          recover Array[Array[String]] end
        for addr in arg.split(",").values() do
          o_addrs_write.push(addr.split(":"))
        end
        so.output_addrs = consume o_addrs_write
      | ("control", let arg: String) =>
        so.c_addr = arg.split(":")
        so.c_host = so.c_addr(0)
        so.c_service = so.c_addr(1)
      | ("data", let arg: String) =>
        let d_addr_ref = arg.split(":")
        let d_addr_trn: Array[String] trn = recover Array[String] end
        d_addr_trn.push(d_addr_ref(0))
        d_addr_trn.push(d_addr_ref(1))
        so.d_addr = consume d_addr_trn
        so.d_host = so.d_addr(0)
        so.d_service = so.d_addr(1)
      | ("my-control", let arg: String) =>
        so.my_c_addr = arg.split(":")
        so.my_c_host = so.my_c_addr(0)
        so.my_c_service = so.my_c_addr(1)
      | ("my-data", let arg: String) =>
        so.my_d_addr = arg.split(":")
        so.my_d_host = so.my_d_addr(0)
        so.my_d_service = so.my_d_addr(1)
      | ("phone-home", let arg: String) => so.p_arg = arg.split(":")
      | ("worker-count", let arg: I64) =>
        so.worker_count = arg.usize()
      | ("topology-initializer", None) =>
        so.is_initializer = true
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
      | ("stop-pause", let arg: I64) =>
        so.stop_the_world_pause = arg.u64()
      | ("spike-seed", let arg: I64) => spike_seed = arg.u64()
      | ("spike-drop", None) => spike_drop = true
      | ("spike-prob", let arg: F64) => spike_prob = arg
      | ("spike-margin", let arg: I64) => spike_margin = arg.usize()
      end
    end

    if so.worker_count == 1 then
      so.is_initializer = true
    end
    if so.is_initializer then
      so.worker_name = "initializer"
    end

    ifdef "spike" then
      so.spike_config = SpikeConfig(spike_drop, spike_prob, spike_margin,
        spike_seed)
      let sc = so.spike_config as SpikeConfig

      @printf[I32](("|||Spike seed: " + sc.seed.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike drop: " + sc.drop.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike prob: " + sc.prob.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike margin: " + sc.margin.string() +
        "|||\n").cstring())
    end

    var o = Options(options.remaining(), false)

    (so, options.remaining())
