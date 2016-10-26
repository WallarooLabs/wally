use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "wallaroo/initialization"
use "wallaroo/network"
use "wallaroo/topology"
use "wallaroo/resilience"

interface AppStarter
  fun apply(env: Env, data_addr: Array[String] val,
    input_addrs: Array[Array[String]] val, 
    output_addr: Array[String] val, metrics_conn: TCPConnection, 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (WorkerInitializer | None)) ? 

actor Startup
  new create(env: Env, app_runner: (AppStarter val | Application val), event_log_file: (String val | None)) =>
    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var c_arg: (Array[String] | None) = None
    var d_arg: (Array[String] | None) = None
    var p_arg: (Array[String] | None) = None
    var i_addrs_write: Array[Array[String]] trn = 
      recover Array[Array[String]] end
    var expected: USize = 1_000_000
    var init_path = ""
    var worker_count: USize = 1
    var is_initializer = false
    var worker_initializer: (WorkerInitializer | None) = None
    let alfred = Alfred(env, event_log_file)
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
        .add("phone-home", "p", StringArgument)
        .add("file", "f", StringArgument)
        // worker count includes the initial "leader" since there is no
        // persisting leader
        .add("worker-count", "w", I64Argument)
        .add("topology-initializer", "t", None)
        .add("leader", "l", None)
        .add("name", "n", StringArgument)

      for option in options do
        match option
        | ("expected", let arg: I64) => expected = arg.usize()
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("in", let arg: String) => 
          for addr in arg.split(",").values() do
            i_addrs_write.push(addr.split(":"))
          end
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("control", let arg: String) => c_arg = arg.split(":")
        | ("data", let arg: String) => d_arg = arg.split(":")
        | ("phone-home", let arg: String) => p_arg = arg.split(":")
        | ("file", let arg: String) => init_path = arg
        | ("worker-count", let arg: I64) => 
          worker_count = arg.usize()
        | ("topology-initializer", None) => is_initializer = true
        | ("name", let arg: String) => worker_name = arg
        end
      end

      if worker_count == 1 then is_initializer = true end

      if is_initializer then worker_name = "initializer" end

      let input_addrs: Array[Array[String]] val = consume i_addrs_write
      let m_addr = m_arg as Array[String]
      let c_addr = c_arg as Array[String]
      let c_host = c_addr(0)
      let c_service = c_addr(1)

      let o_addr_ref = o_arg as Array[String]
      let o_addr_trn: Array[String] trn = recover Array[String] end
      o_addr_trn.push(o_addr_ref(0))
      o_addr_trn.push(o_addr_ref(1))
      let o_addr: Array[String] val = consume o_addr_trn

      let d_addr_ref = d_arg as Array[String]
      let d_addr_trn: Array[String] trn = recover Array[String] end
      d_addr_trn.push(o_addr_ref(0))
      d_addr_trn.push(o_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn

      let d_host = d_addr(0)
      let d_service = d_addr(1)

      if worker_name == "" then
        env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = TCPConnection(connect_auth,
          OutNotify("metrics"),
          m_addr(0),
          m_addr(1))

      (let ph_host, let ph_service) = 
        match p_arg
        | let addr: Array[String] => 
          (addr(0), addr(1))
        else
          ("", "")
        end

      let connections = Connections(worker_name, env, auth, c_host, c_service, 
        d_host, d_service, ph_host, ph_service, is_initializer)

      let local_topology_initializer = LocalTopologyInitializer(worker_name, 
        env, auth, connections, metrics_conn, is_initializer, alfred)

      if is_initializer then
        env.out.print("Running as Initializer...")
        let application_initializer = ApplicationInitializer(
          local_topology_initializer, input_addrs, o_addr, alfred)

        worker_initializer = WorkerInitializer(auth, worker_count, connections,
          application_initializer, d_addr, metrics_conn)
        worker_name = "initializer"
      end

      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(worker_name, env, auth, connections, 
          is_initializer, worker_initializer, local_topology_initializer, alfred)

      if is_initializer then
        connections.register_listener(
          TCPListener(auth, consume control_notifier, c_host, c_service) 
        )
      else
        connections.register_listener(
          TCPListener(auth, consume control_notifier) 
        )
      end

      match app_runner
      | let application: Application val =>
        match worker_initializer 
        | let w: WorkerInitializer =>
          w.start(application)
        end
      | let starter: AppStarter val =>
        starter(env, d_addr, input_addrs, o_addr, metrics_conn, expected,
          init_path, worker_count, is_initializer, worker_name, connections, 
          worker_initializer)
      end
    else
      StartupHelp(env)
    end
