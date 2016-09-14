use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"

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
    initializer: Bool, node_name: String) ? 

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
    var node_name = ""
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
        .add("node-name", "n", StringArgument)

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
        | ("node-name", let arg: String) => node_name = arg
        end
      end

      let m_addr = m_arg as Array[String]
      let o_addr = o_arg as Array[String]

      if node_name == "" then
        env.out.print("You must specify a node name via --node-name/-n.")
        error
      end

      app_runner(env, input_addrs, o_addr, m_addr, expected, init_path, 
        worker_count, initializer, node_name)
    else
      JrStartupHelp(env)
    end