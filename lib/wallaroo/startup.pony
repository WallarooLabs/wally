use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "./network"

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
    initializer: Bool, worker_name: String, connections: Connections) ? 

actor Startup
  new create(env: Env, app_runner: AppStarter val) =>
    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var c_arg: (Array[String] | None) = None
    var d_arg: (Array[String] | None) = None
    var input_addrs: Array[Array[String]] = input_addrs.create()
    var expected: USize = 1_000_000
    var init_path = ""
    var worker_count: USize = 1
    var is_initializer = false
    var worker_name = ""
    try
      var options = Options(env.args)
      var auth = env.root as AmbientAuth

      options
        .add("expected", "e", I64Argument)
        .add("metrics", "m", StringArgument)
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)
        .add("control", "c", StringArgument)
        .add("data", "d", StringArgument)
        .add("file", "f", StringArgument)
        // worker count includes the initial "leader" since there is no
        // persisting leader
        .add("worker-count", "w", I64Argument)
        .add("topology-initializer", "t", None)
        .add("worker-name", "n", StringArgument)

      for option in options do
        match option
        | ("expected", let arg: I64) => expected = arg.usize()
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("in", let arg: String) => 
          for addr in arg.split(",").values() do
            input_addrs.push(addr.split(":"))
          end
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("control", let arg: String) => c_arg = arg.split(":")
        | ("data", let arg: String) => d_arg = arg.split(":")
        | ("file", let arg: String) => init_path = arg
        | ("worker-count", let arg: I64) => worker_count = arg.usize()
        | ("topology-initializer", None) => is_initializer = true
        | ("worker-name", let arg: String) => worker_name = arg
        end
      end

      let m_addr = m_arg as Array[String]
      let o_addr = o_arg as Array[String]
      let c_addr = c_arg as Array[String]
      let c_host = c_addr(0)
      let c_service = c_addr(1)
      let d_addr = d_arg as Array[String]
      let d_host = d_addr(0)
      let d_service = d_addr(1)

      if worker_name == "" then
        env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      let connections = Connections(worker_name, env, auth, c_host, c_service, 
        d_host, d_service, is_initializer)

      if is_initializer then
        let control_notifier: TCPListenNotify iso =
          ControlChannelNotifier(env, auth, worker_name, connections, true)
        TCPListener(auth, consume control_notifier, c_host, c_service) 

        let data_notifier: TCPListenNotify iso =
          DataChannelListenerNotifier(worker_name, env, auth, 
            connections, is_initializer)
        TCPListener(auth, consume data_notifier, d_host, d_service)
      end

      app_runner(env, input_addrs, o_addr, m_addr, expected, init_path, 
        worker_count, is_initializer, worker_name, connections)
    else
      JrStartupHelp(env)
    end