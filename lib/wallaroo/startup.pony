use "buffered"
use "collections"
use "files"
use "net"
use "net/http"
use "options"
use "time"
use "sendence/hub"
use "wallaroo/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/spike"
use "wallaroo/topology"

actor Startup
  let _env: Env
  let _application: Application val
  let _app_name: (String | None)
  var _m_arg: (Array[String] | None) = None
  var _o_arg: (Array[String] | None) = None
  var _c_arg: (Array[String] | None) = None
  var _d_arg: (Array[String] | None) = None
  var _my_c_addr: Array[String] = ["", "0"]
  var _my_d_addr: Array[String] = ["", "0"]
  var _p_arg: (Array[String] | None) = None
  var _j_arg: (Array[String] | None) = None
  var _a_arg: (String | None) = None
  var _i_addrs_write: Array[Array[String]] trn =
    recover Array[Array[String]] end
  var _ph_host: String = ""
  var _ph_service: String = ""
  var _worker_count: USize = 1
  var _is_initializer: Bool = false
  var _is_multi_worker: Bool = true
  var _is_joining: Bool = false
  var _is_swarm_managed: Bool = false
  var _worker_initializer: (WorkerInitializer | None) = None
  var _application_initializer: (ApplicationInitializer | None) = None
  var _worker_name: String = ""
  var _resilience_dir: String = "/tmp"
  var _swarm_manager_addr: String = ""
  var _event_log_file: String = ""
  var _local_topology_file: String = ""
  var _data_channel_file: String = ""
  var _control_channel_file: String = ""
  var _worker_names_file: String = ""
  var _connection_addresses_file: String = ""
  var _alfred: (Alfred | None) = None
  var _alfred_file_length: (USize | None) = None
  var _joining_listener: (TCPListener | None) = None
  var _spike_seed: (U64 | None) = None
  var _spike_drop: Bool = false
  var _spike_prob: (U64 | None) = None
  var _spike_config: (SpikeConfig | None) = None

  new create(env: Env, application: Application val,
    app_name: (String | None))
  =>
    _env = env
    _application = application
    _app_name = app_name
    ifdef "resilience" then
      @printf[I32]("****RESILIENCE is active****\n".cstring())
    end
    ifdef "trace" then
      @printf[I32]("****TRACE is active****\n".cstring())
    end
    ifdef "spike" then
      @printf[I32]("****SPIKE is active****\n".cstring())
    end

    try
      var options = Options(_env.args, false)
      let auth = _env.root as AmbientAuth

      options
        .add("expected", "e", I64Argument)
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
        .add("alfred-file-length", "l", I64Argument)
        // pass in control address of any worker as the value of this parameter
        // to join a running cluster
        // TODO: Actually make a joining worker a first class citizen.
        // All this does is give the new worker metrics info so it can
        // register with the UI (a "nominal join").
        .add("join", "j", StringArgument)
        .add("swarm-managed", "s", None)
        .add("swarm-manager-address", "a", StringArgument)
        .add("spike-seed", "", I64Argument)
        .add("spike-drop", "", None)
        .add("spike-prob", "", I64Argument)

      for option in options do
        match option
        | ("expected", let arg: I64) =>
          @printf[I32]("--expected/-e is a deprecated parameter\n".cstring())
        | ("metrics", let arg: String) => _m_arg = arg.split(":")
        | ("in", let arg: String) =>
          for addr in arg.split(",").values() do
            _i_addrs_write.push(addr.split(":"))
          end
        | ("out", let arg: String) => _o_arg = arg.split(":")
        | ("control", let arg: String) => _c_arg = arg.split(":")
        | ("data", let arg: String) => _d_arg = arg.split(":")
        | ("my-control", let arg: String) => _my_c_addr = arg.split(":")
        | ("my-data", let arg: String) => _my_d_addr = arg.split(":")
        | ("phone-home", let arg: String) => _p_arg = arg.split(":")
        | ("worker-count", let arg: I64) =>
          _worker_count = arg.usize()
        | ("topology-initializer", None) => _is_initializer = true
        | ("name", let arg: String) => _worker_name = arg
        | ("resilience-dir", let arg: String) =>
          if arg.substring(arg.size().isize() - 1) == "/" then
            @printf[I32]("--resilience-dir must not end in /\n".cstring())
            error
          else
            _resilience_dir = arg
          end
        | ("alfred-file-length", let arg: I64) =>
          _alfred_file_length = arg.usize()
        | ("join", let arg: String) =>
          _j_arg = arg.split(":")
          _is_joining = true
        | ("swarm-managed", None) => _is_swarm_managed = true
        | ("swarm-manager-address", let arg: String) => _a_arg = arg
        | ("spike-seed", let arg: I64) => _spike_seed = arg.u64()
        | ("spike-drop", None) => _spike_drop = true
        | ("spike-prob", let arg: I64) => _spike_prob = arg.u64()
        end
      end

      if _is_swarm_managed then
        if _a_arg is None then
          @printf[I32](("You must supply '--swarm-manager-address' if " +
            "passing '--swarm-managed'\n").cstring())
          error
        else
          let swarm_manager_url = URL.build(_a_arg as String, false)
          if swarm_manager_url.is_valid() then
            _swarm_manager_addr = _a_arg as String
          else
            @printf[I32](("You must provide a valid URL to " +
              "'--swarm-manager-address'\n").cstring())
            error
          end
        end
      end

      (_ph_host, _ph_service) =
        match _p_arg
        | let addr: Array[String] =>
          try
            (addr(0), addr(1))
          else
            Fail()
            ("", "")
          end
        else
          ("", "")
        end

      let name = match _app_name
        | let n: String => n
        else
          ""
        end

      _event_log_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".evlog"
      _local_topology_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".local-topology"
      _data_channel_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".tcp-data"
      _control_channel_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".tcp-control"
      _worker_names_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".workers"
      _connection_addresses_file = _resilience_dir + "/" + name + "-" +
        _worker_name + ".connection-addresses"

      _alfred = ifdef "resilience" then
          Alfred(_env, _event_log_file
            where backend_file_length = _alfred_file_length)
        else
          Alfred(_env, None)
        end

      ifdef "resilience" then
        @printf[I32](("|||Resilience directory: " + _resilience_dir +
          "|||\n").cstring())
      end

      ifdef "spike" then
        _spike_config = SpikeConfig(_spike_drop, _spike_prob, _spike_seed)
        let sc = _spike_config as SpikeConfig

        @printf[I32](("|||Spike seed: " + sc.seed.string() +
          "|||\n").cstring())
        @printf[I32](("|||Spike drop: " + sc.drop.string() +
          "|||\n").cstring())
        @printf[I32](("|||Spike prob: " + sc.prob.string() +
          "|||\n").cstring())
      end

      if _is_joining then
        @printf[I32]("New worker preparing to join cluster\n".cstring())
      else
        if _worker_count == 1 then
          @printf[I32]("Single worker topology\n".cstring())
          _is_initializer = true
          _is_multi_worker = false
        else
          @printf[I32]((_worker_count.string() + " worker topology\n").cstring())
        end
      end

      if _is_initializer then _worker_name = "initializer" end

      // TODO: When we add full cluster join functionality, we will probably
      // need to break out initialization branches into primitives.
      // Currently a joining worker only nominally becomes part of the cluster.
      if _is_joining then
        if _worker_name == "" then
          @printf[I32]("You must specify a name for the worker via the -n parameter.\n".cstring())
          error
        end
        let j_addr = _j_arg as Array[String]
        let control_notifier: TCPConnectionNotify iso =
          JoiningControlSenderConnectNotifier(_env, auth, _worker_name,
            this)
        let control_conn: TCPConnection =
          TCPConnection(auth, consume control_notifier, j_addr(0), j_addr(1))
        let cluster_join_msg = ChannelMsgEncoder.join_cluster(_worker_name,
          auth)
        control_conn.writev(cluster_join_msg)
        @printf[I32]("Attempting to join cluster...\n".cstring())
        // This only exists to keep joining worker alive while it waits for
        // cluster information.
        // TODO: Eliminate the need for this.
        _joining_listener =
          TCPListener(auth, JoiningListenNotifier)
      else
        initialize()
      end
    else
      StartupHelp(_env)
    end

  be initialize() =>
    try
      let auth = _env.root as AmbientAuth

      let input_addrs: Array[Array[String]] val =
        (_i_addrs_write = recover Array[Array[String]] end)
      let m_addr = _m_arg as Array[String]
      let c_addr = _c_arg as Array[String]
      let c_host = c_addr(0)
      let c_service = c_addr(1)
      let d_addr_ref = _d_arg as Array[String]
      let d_addr_trn: Array[String] trn = recover Array[String] end
      d_addr_trn.push(d_addr_ref(0))
      d_addr_trn.push(d_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn
      let d_host = d_addr(0)
      let d_service = d_addr(1)

      let my_c_host = _my_c_addr(0)
      let my_c_service = _my_c_addr(1)
      let my_d_host = _my_d_addr(0)
      let my_d_service = _my_d_addr(1)

      let o_addr_ref = _o_arg as Array[String]
      let o_addr_trn: Array[String] trn = recover Array[String] end
      o_addr_trn.push(o_addr_ref(0))
      o_addr_trn.push(o_addr_ref(1))
      let o_addr: Array[String] val = consume o_addr_trn

      if _worker_name == "" then
        _env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      // TODO::joining
      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = MetricsSink(m_addr(0),
          m_addr(1))

      let connect_msg = HubProtocol.connect()
      let metrics_join_msg = HubProtocol.join_metrics(
        "metrics:" + _application.name(),
        _worker_name)
      metrics_conn.writev(connect_msg)
      metrics_conn.writev(metrics_join_msg)

      var is_recovering: Bool = false

      // check to see if we can recover
      ifdef "resilience" then
        let event_log_filepath: FilePath = FilePath(auth, _event_log_file)
        let local_topology_filepath: FilePath = FilePath(auth,
          _local_topology_file)
        let data_channel_filepath: FilePath = FilePath(auth,
          _data_channel_file)
        let control_channel_filepath: FilePath = FilePath(auth,
          _control_channel_file)
        let worker_names_filepath: FilePath = FilePath(auth,
          _worker_names_file)
        let connection_addresses_filepath: FilePath = FilePath(auth,
          _connection_addresses_file)
        if not _is_initializer then
          if event_log_filepath.exists() or
            local_topology_filepath.exists() or
            data_channel_filepath.exists() or
            control_channel_filepath.exists() or
            worker_names_filepath.exists() or
            connection_addresses_filepath.exists()
          then
            if not (event_log_filepath.exists() and
              local_topology_filepath.exists() and
              data_channel_filepath.exists() and
              control_channel_filepath.exists() and
              worker_names_filepath.exists() and
              connection_addresses_filepath.exists())
            then
              @printf[I32](("Some of the resilience recovery files are" +
                " missing but others exist! Cannot continue!\n").cstring())
              Fail()
            else
              @printf[I32]("Recovering from recovery files!\n".cstring())
              // we are recovering because all files exist
              is_recovering = true
            end
          end
        else
          if event_log_filepath.exists() or
            local_topology_filepath.exists() or
            control_channel_filepath.exists() or
            worker_names_filepath.exists()
          then
            if not (event_log_filepath.exists() and
              local_topology_filepath.exists() and
              control_channel_filepath.exists() and
              worker_names_filepath.exists())
            then
              @printf[I32](("Some of the resilience recovery files are" +
                " missing but others exist! Cannot continue!\n").cstring())
              Fail()
            else
              @printf[I32]("Recovering from recovery files!\n".cstring())
              // we are recovering because all files exist
              is_recovering = true
            end
          end
        end
      end

      let connections = Connections(_application.name(), _worker_name, _env,
        auth, c_host, c_service, d_host, d_service, _ph_host, _ph_service,
        metrics_conn, m_addr(0), m_addr(1), _is_initializer,
        _connection_addresses_file, _is_joining, _spike_config)

      let router_registry = RouterRegistry(auth, _worker_name, connections)

      let local_topology_initializer = if _is_swarm_managed then
        let cluster_manager: DockerSwarmClusterManager =
          DockerSwarmClusterManager(auth, _swarm_manager_addr, c_service)
        LocalTopologyInitializer(
          _application, _worker_name, _worker_count, _env, auth, connections,
          router_registry, metrics_conn, _is_initializer, _alfred as Alfred, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file,
          cluster_manager)
      else
        LocalTopologyInitializer(
          _application, _worker_name, _worker_count, _env, auth, connections,
          router_registry, metrics_conn, _is_initializer, _alfred as Alfred, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file)
      end

      if _is_initializer then
        _env.out.print("Running as Initializer...")
        _application_initializer = ApplicationInitializer(auth,
          local_topology_initializer, input_addrs, o_addr, _alfred as Alfred)
        match _application_initializer
        | let ai: ApplicationInitializer =>
          _worker_initializer = WorkerInitializer(auth, _worker_name,
            _worker_count, connections, ai, local_topology_initializer, d_addr,
            metrics_conn)
        end
        _worker_name = "initializer"
      end

      let control_channel_filepath: FilePath = FilePath(auth,
        _control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_worker_name, _env, auth, connections,
        _is_initializer, _worker_initializer, local_topology_initializer,
        _alfred as Alfred, router_registry, control_channel_filepath,
        my_d_host, my_d_service)

      ifdef "resilience" then
        if _is_initializer then
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            c_host, c_service)
        else
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            my_c_host, my_c_service)
        end
      else
        if _is_initializer then
          connections.register_listener(
            TCPListener(auth, consume control_notifier, c_host, c_service))
        else
          connections.register_listener(
            TCPListener(auth, consume control_notifier, my_c_host,
              my_c_service))
        end
      end

      ifdef "resilience" then
        if is_recovering then
          // need to do this before recreating the data connection as at
          // that point replay starts
          let worker_names_filepath: FilePath = FilePath(auth,
            _worker_names_file)
          let recovered_workers = _recover_worker_names(
            worker_names_filepath)
          if _is_multi_worker then
            local_topology_initializer.recover_and_initialize(
              recovered_workers, _worker_initializer)
          end
        end
      end

      if not is_recovering then
        match _worker_initializer
        | let w: WorkerInitializer =>
          w.start(_application)
        end
      end

      if _is_joining then
        // Dispose of temporary listener
        match _joining_listener
        | let tcp_l: TCPListener =>
          tcp_l.dispose()
        else
          Fail()
        end
      end
    else
      StartupHelp(_env)
    end

  be complete_join(info_sending_host: String, m: InformJoiningWorkerMsg val) =>
    try
      let auth = _env.root as AmbientAuth

      let input_addrs: Array[Array[String]] val =
        (_i_addrs_write = recover Array[Array[String]] end)

      let metrics_conn = MetricsSink(m.metrics_host, m.metrics_service)

      let connect_msg = HubProtocol.connect()
      let metrics_join_msg = HubProtocol.join_metrics(
        "metrics:" + m.metrics_app_name, _worker_name)
      metrics_conn.writev(connect_msg)
      metrics_conn.writev(metrics_join_msg)

      // TODO: Are we creating connections to all addresses or just
      // initializer?
      (let c_host, let c_service) =
        if m.sender_name == "initializer" then
          (info_sending_host, m.control_addrs("initializer")._2)
        else
          m.control_addrs("initializer")
        end
      (let d_host, let d_service) =
        if m.sender_name == "initializer" then
          (info_sending_host, m.data_addrs("initializer")._2)
        else
          m.data_addrs("initializer")
        end

      let my_c_host = _my_c_addr(0)
      let my_c_service = _my_c_addr(1)
      let my_d_host = _my_d_addr(0)
      let my_d_service = _my_d_addr(1)

      let connections = Connections(_application.name(), _worker_name, _env,
        auth, c_host, c_service, d_host, d_service, _ph_host, _ph_service,
        metrics_conn, m.metrics_host, m.metrics_service, _is_initializer,
        _connection_addresses_file, _is_joining, _spike_config)

      let router_registry = RouterRegistry(auth, _worker_name, connections)

      let local_topology_initializer = if _is_swarm_managed then
        let cluster_manager: DockerSwarmClusterManager =
          DockerSwarmClusterManager(auth, _swarm_manager_addr, c_service)
        LocalTopologyInitializer(
          _application, _worker_name, _worker_count, _env, auth, connections,
          router_registry, metrics_conn, _is_initializer, _alfred as Alfred, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file,
          cluster_manager, _is_joining)
      else
        LocalTopologyInitializer(
          _application, _worker_name, _worker_count, _env, auth, connections,
          router_registry, metrics_conn, _is_initializer, _alfred as Alfred, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file
          where is_joining = _is_joining)
      end

      router_registry.set_data_router(DataRouter)
      local_topology_initializer.update_topology(m.local_topology)
      local_topology_initializer.create_data_receivers(m.worker_names,
        my_d_host, my_d_service)

      // Prepare control and data addresses, but sub in correct host for
      // the worker that sent inform message (since it didn't know its
      // host string as seen externally)
      let control_addrs: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      let data_addrs: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      for (worker, addr) in m.control_addrs.pairs() do
        if m.sender_name == worker then
          control_addrs(worker) = (info_sending_host, addr._2)
        else
          control_addrs(worker) = addr
        end
      end
      for (worker, addr) in m.data_addrs.pairs() do
        if m.sender_name == worker then
          data_addrs(worker) = (info_sending_host, addr._2)
        else
          data_addrs(worker) = addr
        end
      end

      // Call this on local topology initializer instead of Connections
      // directly to make sure messages are processed in the create
      // initialization order
      local_topology_initializer.create_connections(consume control_addrs,
        consume data_addrs)

      let control_channel_filepath: FilePath = FilePath(auth,
        _control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_worker_name, _env, auth, connections,
        _is_initializer, _worker_initializer, local_topology_initializer,
        _alfred as Alfred, router_registry, control_channel_filepath,
        my_d_host, my_d_service)

      ifdef "resilience" then
        connections.make_and_register_recoverable_listener(
          auth, consume control_notifier, control_channel_filepath,
          my_c_host, my_c_service)
      else
        connections.register_listener(
          TCPListener(auth, consume control_notifier, my_c_host,
            my_c_service))
      end

      // Dispose of temporary listener
      match _joining_listener
      | let tcp_l: TCPListener =>
        tcp_l.dispose()
      else
        Fail()
      end
    else
      Fail()
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
      @printf[I32]("recover_worker_names: %s\n".cstring(),
        worker_name.cstring())
    end

    ws

