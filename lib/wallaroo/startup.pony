use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "spike"

class OutNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String) =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing connected\n".cstring(),
      _name.null_terminated().cstring())

  fun ref throttled(sock: TCPConnection ref, x: Bool) =>
    if x then
      @printf[None]("%s outgoing throttled\n".cstring(),
        _name.null_terminated().cstring())
    else
      @printf[None]("%s outgoing no longer throttled\n".cstring(),
        _name.null_terminated().cstring())
    end

interface AppStarter
  fun apply(env: Env, input_addrs: Array[Array[String]], 
    output_addr: Array[String], metrics_addr: Array[String], 
    expected: USize, init_path: String, worker_count: USize,
    initializer: Bool, spike_config: SpikeConfig val) ?

actor Startup
  new create(env: Env, app_runner: AppStarter val) =>
    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var d_arg: (Array[String] | None) = None
    var input_addrs: Array[Array[String]] = input_addrs.create()
    var expected: USize = 1_000_000
    var init_path = ""
    var worker_count: USize = 1
    var initializer = false
    var spike_delay = false
    var spike_drop = false
    var spike_seed: U64 = Time.millis()

    try
      var options = Options(env.args)

      options
        .add("expected", "e", I64Argument)
        .add("metrics", "m", StringArgument)
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)
        .add("data", "d", StringArgument)
        .add("file", "f", StringArgument)
        // worker count includes the initial "leader" since there is no
        // persisting leader
        .add("worker-count", "w", I64Argument)
        .add("topology-initializer", "t", None)
        .add("spike-delay", "", None)
        .add("spike-drop", "", None)
        .add("spike-seed", "", I64Argument)

      for option in options do
        match option
        | ("expected", let arg: I64) => expected = arg.usize()
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("in", let arg: String) => 
          for addr in arg.split(",").values() do
            input_addrs.push(addr.split(":"))
          end
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("data", let arg: String) => d_arg = arg.split(":")
        | ("file", let arg: String) => init_path = arg
        | ("worker-count", let arg: I64) => worker_count = arg.usize()
        | ("topology-initializer", None) => initializer = true
        | ("spike-delay", None) =>
          env.out.print("%%SPIKE-DELAY%%")
          spike_delay = true
        | ("spike-drop", None) =>
          env.out.print("%%SPIKE-DROP%%")
          spike_drop = true
        | ("spike-seed", let arg: I64) => spike_seed = arg.u64()
          end
      end

      let m_addr = m_arg as Array[String]
      let o_addr = o_arg as Array[String]

      env.out.print("Using Spike seed " + spike_seed.string())
      let spike_config = SpikeConfig(spike_delay, spike_drop, spike_seed)
      app_runner(env, input_addrs, o_addr, m_addr, expected, init_path, 
        worker_count, initializer, spike_config)
    else
      JrStartupHelp(env)
    end
