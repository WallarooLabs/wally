use "buffered"
use "collections"
use "files"
use "net"
use "options"
use "time"
use "sendence/hub"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"

actor Startup
  new create(env: Env, application: Application val,
    app_name: (String val | None))
  =>
    ifdef "backpressure" then
      env.out.print("****BACKPRESSURE is active****")
    end
    ifdef "resilience" then
      env.out.print("****RESILIENCE is active****")
    end
    ifdef "trace" then
      env.out.print("****TRACE is active****")
    end

    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var c_arg: (Array[String] | None) = None
    var d_arg: (Array[String] | None) = None
    var p_arg: (Array[String] | None) = None
    var i_addrs_write: Array[Array[String]] trn =
      recover Array[Array[String]] end
    var worker_count: USize = 1
    var is_initializer = false
    var worker_initializer: (WorkerInitializer | None) = None
    var worker_name = ""
    try
      var options = Options(env.args, false)
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
        | ("expected", let arg: I64) =>
          env.out.print("--expected/-e is a deprecated parameter")
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("in", let arg: String) =>
          for addr in arg.split(",").values() do
            i_addrs_write.push(addr.split(":"))
          end
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("control", let arg: String) => c_arg = arg.split(":")
        | ("data", let arg: String) => d_arg = arg.split(":")
        | ("phone-home", let arg: String) => p_arg = arg.split(":")
        | ("worker-count", let arg: I64) =>
          worker_count = arg.usize()
        | ("topology-initializer", None) => is_initializer = true
        | ("name", let arg: String) => worker_name = arg
        end
      end

      if worker_count == 1 then
        env.out.print("Single worker topology")
        is_initializer = true
      else
        env.out.print(worker_count.string() + " worker topology")
      end

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
      d_addr_trn.push(d_addr_ref(0))
      d_addr_trn.push(d_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn

      let d_host = d_addr(0)
      let d_service = d_addr(1)

      if worker_name == "" then
        env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = MetricsSink(m_addr(0),
          m_addr(1))

      let connect_msg = HubProtocol.connect()
      let metrics_join_msg = HubProtocol.join("metrics:" + application.name())
      metrics_conn.writev(connect_msg)
      metrics_conn.writev(metrics_join_msg)

      (let ph_host, let ph_service) =
        match p_arg
        | let addr: Array[String] =>
          (addr(0), addr(1))
        else
          ("", "")
        end

      let connections = Connections(application.name(), worker_name, env, auth,
        c_host, c_service, d_host, d_service, ph_host, ph_service,
        metrics_conn, is_initializer)

      let name =  match app_name
        | let n: String => n
        else
          ""
        end
      let event_log_file = "/tmp/" + name + "-" + worker_name + ".evlog"
      let local_topology_file = "/tmp/" + name + "-" +
          worker_name + ".local-topology"
      let data_channel_file = "/tmp/" + name + "-" + worker_name + ".tcp-data"
      let control_channel_file = "/tmp/" + name + "-" + worker_name +
          ".tcp-control"
      let worker_names_file = "/tmp/" + name + "-" + worker_name + ".workers"

      let alfred = Alfred(env, event_log_file)
      let local_topology_initializer = LocalTopologyInitializer(
        application, worker_name, worker_count, env, auth, connections,
        metrics_conn, is_initializer, alfred, input_addrs,
        local_topology_file, data_channel_file, worker_names_file)

      if is_initializer then
        env.out.print("Running as Initializer...")
        // TODO: Currently, an initializer cannot recover because it's
        // the home of sources.
        ifdef "resilience" then
          Fail()
        end
        let application_initializer = ApplicationInitializer(auth,
          local_topology_initializer, input_addrs, o_addr, alfred)

        worker_initializer = WorkerInitializer(auth, worker_count, connections,
          application_initializer, local_topology_initializer, d_addr,
          metrics_conn)
        worker_name = "initializer"
      end

      let control_channel_filepath: FilePath = FilePath(auth, control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(worker_name, env, auth, connections,
        is_initializer, worker_initializer, local_topology_initializer,
        alfred, control_channel_filepath)

      ifdef "resilience" then
        if is_initializer then
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            c_host, c_service)
        else
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath)
        end
      else
        if is_initializer then
          connections.register_listener(
            TCPListener(auth, consume control_notifier, c_host, c_service))
        else
          connections.register_listener(
            TCPListener(auth, consume control_notifier))
        end
      end

      ifdef "resilience" then
        // If the file worker_names_file exists we need to recover the list of
        // known workers and recreate the data receivers
        let worker_names_filepath: FilePath = FilePath(auth, worker_names_file)
        if worker_names_filepath.exists() then
          let recovered_workers = _recover_worker_names(worker_names_filepath)
          local_topology_initializer.create_data_receivers(recovered_workers,
            worker_initializer)
        end
      end

      // TODO: We are not recreating the control channel connection from upstream!

      match worker_initializer
      | let w: WorkerInitializer =>
        w.start(application)
      end

    else
      StartupHelp(env)
    end


  fun ref _recover_worker_names(worker_names_filepath: FilePath):
    Array[String] val
  =>
    """
    Read in a list of the names of all workers after recovery.
    """
    let ws: Array[String] trn = recover Array[String] end

    let file = File(worker_names_filepath)
    for worker_name in file.lines() do
      ws.push(worker_name)
      @printf[I32](("recover_worker_names: " + worker_name).cstring())
    end

    ws

