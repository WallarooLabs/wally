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
    var resilience_dir = "/tmp"
    var alfred_file_length: (USize | None) = None
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
        .add("name", "n", StringArgument)
        .add("resilience-dir", "r", StringArgument)
        .add("alfred-file-length", "l", I64Argument)

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
        | ("resilience-dir", let arg: String) =>
          if arg.substring(arg.size().isize() - 1) == "/" then
            env.out.print("--resilience-dir must not end in /")
            error
          else
            resilience_dir = arg
          end
        | ("alfred-file-length", let arg: I64) =>
          alfred_file_length = arg.usize()
        end
      end

      ifdef "resilience" then
        env.out.print("|||Resilience directory: " + resilience_dir + "|||")
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

      let name =  match app_name
        | let n: String => n
        else
          ""
        end
      let event_log_file = resilience_dir + "/" + name + "-" +
        worker_name + ".evlog"
      let local_topology_file = resilience_dir + "/" + name + "-" +
        worker_name + ".local-topology"
      let data_channel_file = resilience_dir + "/" + name + "-" + worker_name +
        ".tcp-data"
      let control_channel_file = resilience_dir + "/" + name + "-" +
        worker_name + ".tcp-control"
      let worker_names_file = resilience_dir + "/" + name + "-" + worker_name +
        ".workers"
      let connection_addresses_file = resilience_dir + "/" + name + "-" +
        worker_name + ".connection-addresses"

      var recovering: Bool = false

      // check to see if we can recover
      ifdef "resilience" then
        let event_log_filepath: FilePath = FilePath(auth, event_log_file)
        let local_topology_filepath: FilePath = FilePath(auth,
          local_topology_file)
        let data_channel_filepath: FilePath = FilePath(auth, data_channel_file)
        let control_channel_filepath: FilePath = FilePath(auth,
          control_channel_file)
        let worker_names_filepath: FilePath = FilePath(auth, worker_names_file)
        let connection_addresses_filepath: FilePath = FilePath(auth,
          connection_addresses_file)
        if not is_initializer then
          if event_log_filepath.exists() or
             local_topology_filepath.exists() or
             data_channel_filepath.exists() or
             control_channel_filepath.exists() or
             worker_names_filepath.exists() or
             connection_addresses_filepath.exists() then

            if not (event_log_filepath.exists() and
               local_topology_filepath.exists() and
               data_channel_filepath.exists() and
               control_channel_filepath.exists() and
               worker_names_filepath.exists() and
               connection_addresses_filepath.exists()) then

              @printf[I32](("Some of the resilience recovery files are" +
                " missing but others exist! Cannot continue!\n").cstring())
              Fail()
            else
              @printf[I32]("Recovering from recovery files!!\n".cstring())
              // we are recovering because all files exist
              recovering = true
            end
          end
        else
          if event_log_filepath.exists() or
             local_topology_filepath.exists() or
             control_channel_filepath.exists() or
             worker_names_filepath.exists() then

            if not (event_log_filepath.exists() and
               local_topology_filepath.exists() and
               control_channel_filepath.exists() and
               worker_names_filepath.exists()) then

              @printf[I32](("Some of the resilience recovery files are" +
                " missing but others exist! Cannot continue!\n").cstring())
              Fail()
            else
              @printf[I32]("Recovering from recovery files!!\n".cstring())
              // we are recovering because all files exist
              recovering = true
            end
          end
        end
      end

      let alfred = ifdef "resilience" then
          Alfred(env, event_log_file
            where backend_file_length = alfred_file_length)
        else
          Alfred(env, None)
        end

      let connections = Connections(application.name(), worker_name, env, auth,
        c_host, c_service, d_host, d_service, ph_host, ph_service,
        metrics_conn, is_initializer, connection_addresses_file)

      let local_topology_initializer = LocalTopologyInitializer(
        application, worker_name, worker_count, env, auth, connections,
        metrics_conn, is_initializer, alfred, input_addrs,
        local_topology_file, data_channel_file, worker_names_file)

      if is_initializer then
        env.out.print("Running as Initializer...")
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
        if recovering then
          // need to do this before recreating the data connection as at that point
          // replay starts
          let worker_names_filepath: FilePath = FilePath(auth, worker_names_file)
          let recovered_workers = _recover_worker_names(worker_names_filepath)
          local_topology_initializer.recover_and_initialize(recovered_workers,
            worker_initializer)
        end
      end

      if not recovering then
        match worker_initializer
        | let w: WorkerInitializer =>
          w.start(application)
        end
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

