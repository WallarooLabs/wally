/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "assert"
use "collections"
use "files"
use "time"
use "wallaroo_labs/messages"
use "net"
use "signals"
use "wallaroo_labs/options"
use "ini"
use "process"
use "wallaroo_labs/tcp"
use "regex"


primitive Booting is Stringable
  fun string(): String iso^ =>
      "Booting".string()

primitive Ready is Stringable
  fun string(): String iso^ =>
      "Ready".string()

primitive Started is Stringable
  fun string(): String iso^ =>
      "Started".string()

primitive TopologyReady is Stringable
  fun string(): String iso^ =>
      "TopologyReady".string()

primitive Done is Stringable
  fun string(): String iso^ =>
      "Done".string()

primitive Killed is Stringable
  fun string(): String iso^ =>
      "Killed".string()

primitive DoneShutdown is Stringable
  fun string(): String iso^ =>
      "DoneShutdown".string()

primitive StartSenders is Stringable
  fun string(): String iso^ =>
      "StartSenders".string()

primitive SendersReady is Stringable
  fun string(): String iso^ =>
      "SendersReady".string()

primitive SendersStarted is Stringable
  fun string(): String iso^ =>
      "SendersStarted".string()

primitive SendersDone is Stringable
  fun string(): String iso^ =>
      "SendersDone".string()

primitive SendersDoneShutdown is Stringable
  fun string(): String iso^ =>
      "SendersDoneShutdown".string()

primitive AwaitingSendersReady is Stringable
  fun string(): String iso^ =>
      "AwaitingSendersReady".string()

primitive AwaitingSendersStart is Stringable
  fun string(): String iso^ =>
      "AwaitingSendersStart".string()

primitive AwaitingSendersDoneShutdown is Stringable
  fun string(): String iso^ =>
      "AwaitingSendersDoneShutdown".string()

primitive TopologyDoneShutdown is Stringable
  fun string(): String iso^ =>
      "TopologyDoneShutdown".string()

primitive Initialized is Stringable
  fun string(): String iso^ =>
      "Booting".string()

primitive ErrorShutdown is Stringable
  fun string(): String iso^ =>
      "ErrorShutdown".string()


type DagonState is
  ( Initialized
  | Booting
  | TopologyReady
  | AwaitingSendersReady
  | AwaitingSendersStart
  | AwaitingSendersDoneShutdown
  | StartSenders
  | SendersReady
  | SendersStarted
  | SendersDone
  | SendersDoneShutdown
  | TopologyDoneShutdown
  | ErrorShutdown
  | Done
  )

type ChildState is
  ( Booting
  | Ready
  | Started
  | TopologyReady
  | Done
  | DoneShutdown
  | Killed
  )


actor Main

  new create(env: Env) =>
    """
    Check if we have all commandline arguments. If no args where
    given run the tests.
    TODO: Run tests if list of args is empty.
    """
    var required_args_are_present = true
    var docker_host: (String | None) = None
    var docker_path: (String | None) = None
    var docker_tag: (String | None) = None
    var docker_network: (String | None) = None
    var docker_userid: (String | None) = None
    var metrics_addr: (String | None) = None
    var docker_arch: String = ""
    var use_docker: Bool = false
    var timeout: (I64 | None) = None
    var ini_path: (String | None) = None
    var p_arg: (Array[String] | None) = None
    var phone_home_host: String = ""
    var phone_home_service: String = ""
    var service: String = ""
    var options = Options(env.args)
    var delay_senders = false

    options
    .add("docker", "d", StringArgument)
    .add("docker-tag", "T", StringArgument)
    .add("docker-network", "N", StringArgument)
    .add("docker-arch", "A", StringArgument)
    .add("docker-path", "P", StringArgument)
    .add("docker-userid", "U", StringArgument)
    .add("metrics-addr", "M", StringArgument)
    .add("timeout", "t", I64Argument)
    .add("filepath", "f", StringArgument)
    .add("phone-home", "h", StringArgument)
    .add("delay-senders", "D", None)
    try
      for option in options do
        match option
        | ("docker", let arg: String) => docker_host = arg
        | ("docker-tag", let arg: String) => docker_tag = arg
        | ("docker-network", let arg: String) => docker_network = arg
        | ("docker-arch", let arg: String) => docker_arch = arg
        | ("docker-path", let arg: String) => docker_path = arg
        | ("docker-userid", let arg: String) => docker_userid = arg
        | ("metrics-addr", let arg: String) => metrics_addr = arg
        | ("timeout", let arg: I64) => timeout = arg
        | ("filepath", let arg: String) => ini_path = arg
        | ("phone-home", let arg: String) => p_arg = arg.split(":")
        | ("delay-senders", None) => delay_senders = true
        | let err: ParseError =>
          err.report(env.err)
          error
        end
      end
    else
      env.err.print("""dagon: usage: [
--docker=<host:port>
--docker-tag/-T <docker-tag>
--docker-network/-N <docker-network>
--docker-arch/-A <docker-arch>
--docker-path/-P <docker-path>
--docker-userid/-U <docker-userid>]
--metrics-addr/-M <metrics-addr>
--timeout/-t <seconds>
--filepath/-f <path>
--phone-home/-h <host:port>
--delay-senders/-D""")
      return
    end

    try
      if docker_host isnt None then
        env.out.print("dagon: DOCKER_HOST: " + (docker_host as String))
        use_docker = true
      else
        env.out.print("dagon: no DOCKER_HOST defined, using processes.")
        docker_host = ""
      end

      if docker_tag isnt None then
        env.out.print("dagon: docker_tag: " + (docker_tag as String))
      else
        docker_tag = ""
      end

      if docker_userid isnt None then
        env.out.print("dagon: docker_userid: " + (docker_userid as String))
      else
        docker_userid = ""
      end

      if docker_path isnt None then
        env.out.print("dagon: docker_path: " + (docker_path as String))
      else
        docker_path = ""
      end

      if docker_network isnt None then
        env.out.print("dagon: docker_network: " + (docker_network as String))
      else
        docker_network = ""
      end

      if timeout is None then
        env.err.print("dagon: Must supply required '--timeout' argument")
        required_args_are_present = false
      elseif (timeout as I64) < 0 then
        env.err.print("dagon: timeout can't be negative")
        required_args_are_present = false
      end

      if ini_path is None then
        env.err.print("dagon error: Must supply required '--filepath' argument")
        required_args_are_present = false
      end

      if p_arg is None then
        env.err.print("dagon error: Must supply required '--phone-home' argument")
        required_args_are_present = false
      elseif (p_arg as Array[String]).size() != 2 then
        env.err.print(
        "dagon error: '--dagon' argument must be in format: '127.0.0.1:8080")
        required_args_are_present = false
      end

      if not required_args_are_present then
        env.err.print("dagon: error parsing arguments. Bailing out!")
        return
      end

      env.out.print("dagon: timeout: " + timeout.string())
      env.out.print("dagon: ini_path: " + (ini_path as String))

      phone_home_host = (p_arg as Array[String])(0)
      phone_home_service = (p_arg as Array[String])(1)

      env.out.print("dagon: host: " + phone_home_host)
      env.out.print("dagon: service: " + phone_home_service)

      ProcessManager(env, delay_senders, use_docker, docker_host as String,
        docker_tag as String, timeout as I64, ini_path as String,
        phone_home_host, phone_home_service, docker_network as String,
        docker_arch, metrics_addr, docker_userid as String, docker_path
        as String)
    else
      env.err.print("dagon: error parsing arguments")
      env.exitcode(-1)
    end


class Notifier is TCPListenNotify
  let _env: Env
  let _p_mgr: ProcessManager

  new create(env: Env, p_mgr: ProcessManager) =>
    _env = env
    _p_mgr = p_mgr

  fun ref listening(listen: TCPListener ref) =>
    var host: String = ""
    var service: String = ""
    try
      (host, service) = listen.local_address().name()
      _env.out.print("dagon: listening on " + host + ":" + service)
      _p_mgr.listening()
    else
      _env.out.print("dagon: couldn't get local address")
      _p_mgr.transition_to(ErrorShutdown)
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("dagon: couldn't listen")
    _p_mgr.transition_to(ErrorShutdown)
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ConnectNotify(_env, _p_mgr)


class ConnectNotify is TCPConnectionNotify
  let _env: Env
  let _p_mgr: ProcessManager
  let _framer: Framer = Framer

  new iso create(env: Env, p_mgr: ProcessManager) =>
    _env = env
    _p_mgr = p_mgr

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(consume chunked)
        match decoded
        | let m: ExternalReadyMsg =>
          _env.out.print("dagon: " + m.node_name + ": Ready")
          _p_mgr.received_ready(conn, m.node_name)
        | let m: ExternalTopologyReadyMsg =>
          _env.out.print("dagon: " + m.node_name + ": TopologyReady")
          _p_mgr.received_topology_ready(conn, m.node_name)
        | let m: ExternalDoneMsg =>
          _env.out.print("dagon: " + m.node_name + ": Done")
          _p_mgr.received_done(conn, m.node_name)
        | let m: ExternalDoneShutdownMsg =>
          _env.out.print("dagon: " + m.node_name + ": DoneShutdown")
          _p_mgr.received_done_shutdown(conn, m.node_name)
        | let m: ExternalStartGilesSendersMsg =>
          _p_mgr.received_start_senders(conn)
        else
          _env.out.print("dagon: Unexpected message from child")
          _p_mgr.transition_to(ErrorShutdown)
          return false
        end
      else
        _env.out.print("dagon: Unable to decode message from child")
        _p_mgr.transition_to(ErrorShutdown)
        return false
      end
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")


class Child
  let name: String
  let host_name: String
  let is_canary: Bool
  let pm: ProcessMonitor
  var conn: (TCPConnection | None) = None
  var state: ChildState = Booting

  new create(name': String, is_canary': Bool, pm': ProcessMonitor, host_name': String) =>
    name = name'
    host_name = host_name'
    is_canary = is_canary'
    pm = pm'


class Node
  let name: String
  let is_canary: Bool
  let is_leader: Bool
  let path: String
  let docker_image: String
  let docker_constraint: String
  let docker_dir: String
  let docker_tag: String
  let docker_userid: String
  let args: Array[String] val
  let wrapper_path: String
  let wrapper_args: Array[String] val
  let vars: Array[String] val
  let host_name: String

  new create(name': String,
    is_canary': Bool, is_leader': Bool,
    path': String,
    wrapper_path': String,
    docker_image': String,
    docker_constraint': String,
    docker_dir': String,
    docker_tag': String,
    docker_userid': String,
    args': Array[String] val,
    wrapper_args': Array[String] val,
    vars': Array[String] val,
    host_name': String)
  =>
    name = name'
    is_canary = is_canary'
    is_leader = is_leader'
    path = path'
    wrapper_path = wrapper_path'
    docker_image = docker_image'
    docker_constraint = docker_constraint'
    docker_dir = docker_dir'
    docker_tag = docker_tag'
    docker_userid = docker_userid'
    args = args'
    wrapper_args = wrapper_args'
    vars = vars'
    host_name = host_name'


actor ProcessManager
  let _env: Env
  let _use_docker: Bool
  let _docker_host: String
  let _docker_tag: String
  let _docker_network: String
  let _docker_path: String
  let _docker_arch: String
  let _docker_userid: String
  let _metrics_addr: (String | None)
  let _timeout: I64
  let _ini_path: String
  let _host: String
  let _service: String
  var _docker_args: Map[String, String] = Map[String, String](4)
  var _docker_vars: Map[String, String] = Map[String, String](3)
  var _canaries: Map[String, Node val] = Map[String, Node val](2)
  var _workers_receivers: Map[String, Node val] = Map[String, Node val](2)
  var _leaders: Map[String, Node val] = Map[String, Node val](1)
  var roster: Map[String, Child] = Map[String, Child]
  var _listener: (TCPListener | None) = None
  var _listener_is_ready: Bool = false
  var _finished_registration: Bool = false
  let _timers: Timers = Timers
  var _listener_timer: (Timer tag | None) = None
  var _processing_timer: (Timer tag | None) = None
  let _name_postfix: String
  var _expect: Bool = false
  var _delay_senders: Bool = false
  var state: DagonState = Initialized

  new create(env: Env, delay_senders: Bool, use_docker: Bool, docker_host: String,
    docker_tag: String,
    timeout: I64, ini_path: String,
    host: String, service: String,
    docker_network: String, docker_arch: String, metrics_addr: (String | None),
    docker_userid: String, docker_path: String)
  =>
    _env = env
    _delay_senders = delay_senders
    _use_docker = use_docker
    _docker_host = docker_host
    _docker_tag = docker_tag
    _docker_network = docker_network
    _docker_path = docker_path
    _docker_arch = docker_arch
    _docker_userid = docker_userid
    _metrics_addr = metrics_addr
    _timeout = timeout
    _ini_path = ini_path
    _host = host
    _service = service
    _name_postfix = Time.wall_to_nanos(Time.now()).string()

    SignalHandler(TermHandler(this), Sig.term())
    SignalHandler(TermHandler(this), Sig.int())

    let tcp_n = recover Notifier(env, this) end
    try
      _listener = TCPListener(env.root as AmbientAuth, consume tcp_n,
      host, service)
      let timer = Timer(WaitForListener(_env, this, _timeout), 0, 2_000_000_000)
      _listener_timer = timer
      _timers(consume timer)
    else
      _env.out.print("Failed creating tcp listener")
      _env.exitcode(-1)
      return
    end

    parse_and_register_nodes()
    transition_to(Booting)

  be listening() =>
    """
    Set listener to ready.
    """
    _listener_is_ready = true
    _env.out.print("dagon: listener is ready!")

  be cancel_timer() =>
    """
    Cancel our WaitForListener timer.
    """
    if _listener_timer isnt None then
      try
        let t = _listener_timer as Timer tag
        _timers.cancel(t)
        _env.out.print("dagon: canceled listener timer")
      else
        _env.out.print("dagon: can't cancel listener timer")
      end
    else
      _env.out.print("dagon: no listener to cancel")
    end

  be cancel_timeout_timer() =>
  """
  Cancel the WaitForProcessingTimer.
  """
  if _processing_timer isnt None then
    try
      let t = _processing_timer as Timer tag
      _timers.cancel(t)
      _env.out.print("dagon: canceled processing timer")
    else
      _env.out.print("dagon: can't cancel processing timer")
    end
  else
    _env.out.print("dagon: no processing timer to cancel")
  end

  be boot_topology() =>
    """
    Check if listener is ready and boot if so.
    """
    if _listener_is_ready and _finished_registration then
      _env.out.print("dagon: cancelling timer")
      cancel_timer()
      _env.out.print("dagon: listener is ready and nodes are " +
        "registered. Booting topology.")
      boot_leaders()
    else
      _env.out.print("dagon: listener is not ready.")
    end

  be parse_and_register_nodes() =>
    """
    Parse ini file and register process nodes
    """
    _env.out.print("dagon: parse_and_register_nodes")
    var ini_file: (File | None) = None
    try
      ini_file = _file_from_path(_env.root as AmbientAuth, _ini_path)
    else
      _env.out.print("dagon: can't read File from path: " + _ini_path)
      transition_to(ErrorShutdown)
      return
    end

    if ini_file isnt None then
      let sections = _parse_config(ini_file)
      for section in sections.keys() do
        match section
        | "docker-env" =>
          if _use_docker then
            _docker_vars = _parse_docker_section(sections, section)
          else
            None // Skip because running with processes
          end
        | "docker" =>
          if _use_docker then
            _docker_args = _parse_docker_section(sections, section)
          else
            None // Skip because running with processes
          end
        else
          _parse_node_section(sections, section)
        end
      end
     else
      transition_to(ErrorShutdown)
      return
    end

    // dump docker configs
    if _use_docker then
      _dump_map(_docker_args)
    end

    // we're done with registration
    _env.out.print("dagon: finished registration of nodes")
    _finished_registration = true

  fun ref _parse_config(ini_file: (File | None)): IniMap =>
    """
    Parse the config file.
    """
    var map: IniMap = IniMap()
    try
      map = IniParse((ini_file as File).lines())
    else
      _env.out.print("dagon: failed parsing ini file")
      transition_to(ErrorShutdown)
    end
    map

  fun ref _parse_node_section(sections: IniMap, section: String) =>
    """
    Parse a node section and add node to appropriate map. Use the
    docker_tag set on the commandline as the default tag that can
    be overridden in the configuration file.
    """
    _env.out.print("dagon: parse_node_section")
    let argsbuilder: Array[String] iso = recover Array[String](6) end
    let wrapper_args: Array[String] iso = recover Array[String](4) end
    var name: String = ""
    var host_name: String = ""
    var docker_image = ""
    var docker_constraint = ""
    var docker_dir = ""
    var docker_tag = _docker_tag
    var docker_userid = ""
    var path: String = ""
    var wrapper_path: String = ""
    var is_canary: Bool = false
    var is_leader: Bool = false
    var is_expect: Bool = false
    try
      name = section
      if _use_docker then
        host_name = section + _name_postfix
      else
        host_name = "127.0.0.1"
      end
      argsbuilder.push("--name=" + section)
      for key in sections(section).keys() do
        let final_arg = _replace_placeholders(host_name, name, sections(section)(key))
        match key
        | "docker.image" =>
          docker_image = final_arg
        | "docker.constraint" =>
          docker_constraint = final_arg
        | "docker.dir" =>
          docker_dir = _relative_path_to_ini(final_arg)
        | "docker.tag" =>
          docker_tag = if _docker_tag == "" then final_arg else _docker_tag end
        | "docker.userid" =>
          docker_userid = if _docker_userid == "" then final_arg else _docker_userid end
        | "path" =>
          path = if _use_docker then
                   Path.base(final_arg)
                 else
                   _relative_path_to_ini(final_arg)
                 end
        | "sender" =>
          match sections(section)(key)
            | "true" =>
              is_canary = true
            else
              is_canary = false
            end
        | "metrics" =>
          if _metrics_addr is None then
            argsbuilder.push("--" + key + "=" + final_arg)
          else
            argsbuilder.push("--" + key + "=" + (_metrics_addr as String))
          end
        | "leader" =>
          match sections(section)(key)
          | "true" =>
            is_leader = true
            argsbuilder.push("-l")
          else
            is_leader = false
          end
        | "cluster-initializer" =>
          match sections(section)(key)
          | "true" =>
            is_leader = true
            argsbuilder.push("-t")
          else
            is_leader = false
          end
        | "expect" =>
          is_expect = true
          argsbuilder.push("--" + key + "=" + final_arg)
        | "file" =>
          argsbuilder.push("--" + key + "=" + _relative_path_to_ini(final_arg))
        | "wrapper_path" =>
          wrapper_path = _relative_path_to_ini(final_arg)
        else
          if key.at("wrapper_args") then
            wrapper_args.push(final_arg)
          else
            argsbuilder.push("--" + key + "=" + final_arg)
          end
        end
      end
    else
      _env.out.print("dagon: can't parse node section: " + section)
      transition_to(ErrorShutdown)
      return
    end

    docker_tag = if docker_tag == "" then "latest" else docker_tag end

    argsbuilder.push("--phone-home=" + _host + ":" + _service)
    let a: Array[String] val = consume argsbuilder
    let vars: Array[String] iso = recover Array[String](0) end

    if is_expect and (name == "giles-receiver") then
      _expect = true
    end

    register_node(name, is_canary, is_leader, path, wrapper_path,
      docker_image, docker_constraint, docker_dir,
      docker_tag, docker_userid,
      a, consume wrapper_args, consume vars, host_name)

  fun ref _relative_path_to_ini(path: String): String
  =>
    """
    Make the path relative to the ini file unless it's an absolute path
    """
    Path.join(Path.dir(_ini_path), path)

  fun ref _replace_placeholders(hostname: String, name: String, arg: String):
    String
  =>
    """
    Replace host name placeholders with final values
    """
    var updated_arg = recover val
                        arg.clone().replace("<SELF>", hostname).replace("<NAME>", name)
                      end
    try
      let r = Regex("<([-\\w]+)>")
      updated_arg = if _use_docker then
                      r.replace(updated_arg, ("${1}" + _name_postfix)
                        where global = true)
                    else
                      r.replace(updated_arg, "127.0.0.1" where global = true)
                    end
    end
    updated_arg

  fun ref _parse_docker_section(sections: IniMap, section: String):
    Map[String, String]
  =>
    """
    Parse the docker section and return args as a Map.
    """
    _env.out.print("dagon: parse_docker_section")
    let args: Map[String, String] = Map[String, String]
    try
      for key in sections(section).keys() do
        match key
        | "docker_path" =>
          args(key) = _relative_path_to_ini(sections(section)(key))
        | "DOCKER_CERT_PATH" =>
          args(key) = _relative_path_to_ini(sections(section)(key))
        else
          args(key) = sections(section)(key)
        end
      end

      // override docker path from command line if provided
      if _docker_path != "" then
        args("docker_path") = _docker_path
      end
    else
      _env.out.print("dagon: couldn't parse args in section: " + section)
      transition_to(ErrorShutdown)
    end
    args

  fun ref _file_from_path(auth: AmbientAuth, path: String):
    (File | None)
  =>
    """
    Return a File from a path if we have sufficient permissions to open it.
    TODO: Support restrictive permissions
    """
    var file: (File | None) = None
    try
      file = OpenFile(FilePath(auth, path)) as File
    else
      _env.out.print("dagon: Could not create File: " + path)
      transition_to(ErrorShutdown)
    end
    file

  fun ref _filepath_from_path(path: String): (FilePath | None) =>
    """
    Return a FilePath from a path if we have sufficient permissions to open it.
    TODO: Support restrictive permissions
    """
    var filepath: (FilePath | None) = None
    try
      filepath = FilePath(_env.root as AmbientAuth, path)
    else
      _env.out.print("dagon: Could not create FilePath: " + path)
      transition_to(ErrorShutdown)
    end
    filepath

  fun ref _dump_map(args: Map[String, String]) =>
    """
    Print the args in a map.
    """
    try
      for key in args.keys() do
        _env.out.print("dagon:   key: " + key + "\t" + args(key))
      end
    else
      _env.out.print("dagon: could not dump map of args")
      transition_to(ErrorShutdown)
    end

  fun ref _dump_args(args: Array[String]) =>
    """
    Print the args in an array.
    """
    for value in args.values() do
      _env.out.print("dagon: array value: " + value)
    end

  be shutdown_listener() =>
    """
    Shutdown the listener
    """
    _env.out.print("dagon: shutting down listener")
    if (_listener isnt None) then
      try
        let l = _listener as TCPListener
        l.dispose()
      else
        _env.out.print("dagon: Could not dispose of listener")
      end
    end

  be register_node(name: String,
    is_canary: Bool, is_leader: Bool,
    path: String, wrapper_path: String,
    docker_image: String, docker_constraint: String,
    docker_dir: String, docker_tag: String,
    docker_userid: String,
    args: Array[String] val,
    wrapper_args: Array[String] val,
    vars: Array[String] val,
    host_name: String)
  =>
    """
    Register a node with the appropriate map.
    """
    _env.out.print("dagon: registering node. canary: " + is_canary.string()
      + "; leader: " + is_leader.string() + "; name: " + name)
    let node: Node val = recover Node(name, is_canary, is_leader,
        path, wrapper_path, docker_image, docker_constraint, docker_dir,
        docker_tag, docker_userid,
        args, wrapper_args, vars, host_name) end
    if is_canary then
      _canaries(name) = consume node
    elseif is_leader then
      _leaders(name) = consume node
    else
      _workers_receivers(name) = consume node
    end

  be boot_leaders() =>
    """
    Boot the leader nodes
    """
    _env.out.print("dagon: booting leaders")
    for node in _leaders.values() do
      _env.out.print("dagon: booting leader: " + node.name)
      boot_node(node)
    end

  be boot_workers_receivers() =>
    """
    Boot the worker nodes.
    """
    _env.out.print("dagon: booting workers")
    for node in _workers_receivers.values() do
      _env.out.print("dagon: booting worker: " + node.name)
      boot_node(node)
    end

  be boot_canaries() =>
    """
    Boot the canary nodes.
    """
    _env.out.print("dagon: booting canary nodes")
    for node in _canaries.values() do
      _env.out.print("dagon: booting canary: " + node.name)
      boot_node(node)
    end
    transition_to(AwaitingSendersReady)

  be boot_node(node: Node val) =>
    """
    Boot a node as process or container.
    """
    if _use_docker then
      boot_container(node)
    else
      boot_process(node)
    end

  fun ref kill_child(child: Child ref) =>
    """
    Kill a child (process or container).
    """
    _env.out.print("Killing Child: " + child.name + ", State: " + child.state.string())
    if _use_docker then
      kill_container(child)
    else
      child.pm.dispose()
    end
    child.state = Killed

  fun ref kill_container(child: Child ref) =>
    """
    Kill a child running as a container.
    """
    var docker: (FilePath | None) = None
    var docker_path: String = ""
    var docker_opts: String = ""
    try
      docker_path = _docker_args("docker_path")
      docker = _filepath_from_path(docker_path)
    else
      _env.out.print("dagon: could not get docker info from map")
      transition_to(ErrorShutdown)
      return
    end

    if docker isnt None then
      // prepare the environment
      let vars: Array[String] iso = recover Array[String](4) end
      vars.push("DOCKER_HOST=" + _docker_host)
      // add more specific Docker env variables
      for pair in _docker_vars.pairs() do
        _env.out.print("dagon: adding to docker env: " +
          pair._1 + "=" + pair._2)
        vars.push(pair._1 + "=" + pair._2)
      end

      // prepare the Docker args
      let args: Array[String] iso = recover Array[String](6) end
      args.push(Path.clean(docker_path))   // first arg is always "docker"
      args.push("kill")                         // our Docker command
      args.push(child.host_name)

      // dump args
      let a: Array[String val] val = consume args
      _dump_docker_command(a)

      try
        _env.out.print("dagon: killing docker container: " + child.host_name)
        let pn: ProcessNotify iso = ProcessClient(_env, child.name + "-killer", this)
        let pm: ProcessMonitor = ProcessMonitor(_env.root as AmbientAuth,
          consume pn, docker as FilePath, a, consume vars)
      else
        _env.out.print("dagon: booting docker process failed: " + child.name)
        transition_to(ErrorShutdown)
        return
      end

    else
      _env.out.print("dagon: docker is None: " + child.name)
      transition_to(ErrorShutdown)
      return
    end

  be boot_container(node: Node val) =>
    """
    Boot a node as container.
    """
    _env.out.print("dagon: booting container: " + node.name)

    var docker: (FilePath | None) = None
    var docker_opts: String = ""
    var docker_path: String = ""
    var docker_network: String = _docker_network
    var docker_repo: String = ""
    let docker_arch = if _docker_arch != "" then "." + _docker_arch else "" end
    try
      docker_path = _docker_args("docker_path")
      docker = _filepath_from_path(docker_path)
      docker_network = if docker_network == "" then
                         _docker_args.get_or_else("docker_network", _docker_network)
                       else
                         docker_network
                       end
      docker_repo = _docker_args("docker_repo")
    else
      _env.out.print("dagon: could not get docker info from map")
      transition_to(ErrorShutdown)
      return
    end

    if docker_network == "" then
      _env.out.print("dagon: docker network cannot be empty")
      transition_to(ErrorShutdown)
      return
    end

    if docker isnt None then
      // prepare the environment
      let vars: Array[String] iso = recover Array[String](4) end
      vars.push("DOCKER_HOST=" + _docker_host)
      // add more specific Docker env variables
      for pair in _docker_vars.pairs() do
        _env.out.print("dagon: adding to docker env: " +
          pair._1 + "=" + pair._2)
        vars.push(pair._1 + "=" + pair._2)
      end

      // prepare the Docker args
      let args: Array[String] iso = recover Array[String](6) end
      args.push(Path.clean(docker_path))       // first arg is always "docker"
      args.push("run")                         // our Docker command
      args.push("-u")                          // the userid to use
      args.push(node.docker_userid)
      args.push("--name")                      // the name of the app
      args.push(node.host_name)
      if node.docker_constraint.size() > 0 then
        args.push("-e")                          // add a constraint
        args.push(node.docker_constraint)
      end
      args.push("-h")                          // Docker node name for /etc/hosts
      args.push(node.host_name)
      args.push("--privileged")                // give extended privileges
      // args.push("-d")                          // detach
      args.push("-i")                          // interactive
      args.push("-e")                          // set environment variables
      args.push("LC_ALL=C.UTF-8")
      args.push("-e")                          // set environment variables
      args.push("LANG=C.UTF-8")
      args.push("-v")                          // bind mount a volume
      args.push("/bin:/bin:ro")
      args.push("-v")                          // bind mount a volume
      args.push("/lib:/lib:ro")
      args.push("-v")                          // bind mount a volume
      args.push("/lib64:/lib64:ro")
      args.push("-v")                          // bind mount a volume
      args.push("/usr:/usr:ro")
      args.push("-v")                          // bind mount a volume
      args.push(node.docker_dir + ":" + node.docker_dir)
      args.push("-w")                          // container working dir
      args.push(node.docker_dir)
      args.push("--net=" + docker_network)     // connect to network

      args.push("--entrypoint")                // container entrypoint

      if node.wrapper_path.size() > 0 then // we are wrapping the executable
        args.push(node.wrapper_path)
      else
        args.push(node.path) // the command to run inside the container
      end

      args.push(docker_repo + node.docker_image + docker_arch + ":"
        + node.docker_tag)                     // image path

      if node.wrapper_path.size() > 0 then // we are wrapping the executable
        // append wrapper_args
        for value in node.wrapper_args.values() do
          args.push(value)
        end
        // append node specific args
        args.push(node.path) // the command to run inside the container
        for value in node.args.values() do
          args.push(value)
        end
      else // we are executing directly
        // append node specific args
        for value in node.args.values() do
          args.push(value)
        end
      end

      // dump args
      let a: Array[String val] val = consume args
      _dump_docker_command(a)

      // finally boot the container
      if docker isnt None then
        try
          let pn: ProcessNotify iso = ProcessClient(_env, node.name, this)
          let pm: ProcessMonitor = ProcessMonitor(_env.root as AmbientAuth,
            consume pn, docker as FilePath, a, consume vars)
          let child = Child(node.name, node.is_canary, pm, node.host_name)
            roster.insert(node.name, child)
        else
          _env.out.print("dagon: booting docker process failed: " + node.name)
          transition_to(ErrorShutdown)
          return
        end
      else
        _env.out.print("dagon: docker is None: " + node.name)
        transition_to(ErrorShutdown)
        return
      end

    else
      _env.out.print("dagon: don't have Docker info. Can't boot node.")
      transition_to(ErrorShutdown)
      return
    end

  fun ref _dump_docker_command(args: Array[String val] val) =>
    """
    Dump the full docker command to stdout.
    """
    var command: String = ""
    for value in args.values() do
      command = command + value + " "
    end
    _env.out.print("dagon: docker command\n" + command)

  be boot_process(node: Node val) =>
    """
    Boot a node as a process.
    """
    _env.out.print("dagon: booting process: " + node.name)
    var filepath: (FilePath | None) = None
    var final_args: Array[String] val = recover Array[String](0) end
    if node.wrapper_path.size() > 0 then // wrap if path is set
      filepath = _filepath_from_path(node.wrapper_path)
      final_args = _prepend_arg(Path.clean(node.wrapper_path), _prepend_wrapper(
        node.path, node.wrapper_args, node.args))
    else // normal, unwrapped execution
      filepath = _filepath_from_path(node.path)
      final_args = _prepend_arg(Path.clean(node.path), node.args)
    end
    let final_vars = node.vars
    _env.out.print("dagon: " + node.name + " command: ")
    if node.wrapper_path.size() > 0 then // wrap if path is set
      _env.out.write(node.wrapper_path + " ")
    else
      _env.out.write(node.path + " ")
    end
    for arg in final_args.values() do
      _env.out.write(arg + " ")
    end
    _env.out.write("\n")

    if filepath isnt None then
      try
        let pn: ProcessNotify iso = ProcessClient(_env, node.name, this)
        let pm: ProcessMonitor = ProcessMonitor(_env.root as AmbientAuth,
          consume pn, filepath as FilePath, consume final_args,
          consume final_vars)
        let child = Child(node.name, node.is_canary, pm, node.name)
        roster.insert(node.name, child)
      else
        _env.out.print("dagon: booting process failed")
        transition_to(ErrorShutdown)
        return
      end
    else
      _env.out.print("dagon: filepath is None: " + node.name)
      transition_to(ErrorShutdown)
    end

  fun ref _prepend_arg(new_arg: String,
    args: Array[String] val): Array[String] val
  =>
    let result: Array[String] iso = recover Array[String](7) end
    result.push(new_arg)
    for arg in args.values() do
      result.push(arg)
    end
    result

  fun ref _prepend_wrapper(path: String, wrapper_args: Array[String] val,
    args: Array[String] val): Array[String] val
  =>
    let result: Array[String] iso = recover Array[String](11) end
    for arg in wrapper_args.values() do // wrapper parameters
      result.push(arg)
    end
    result.push(path) // add path to the binary we are wrapping
    for arg in args.values() do // add parameters for our binary
      result.push(arg)
    end
    result

  be send_shutdown(name: String) =>
    """
    Shutdown a running process
    """
    try
      _env.out.print("dagon: sending shutdown to " + name)
      let child = roster(name)
      if child.conn isnt None then
        let c = child.conn as TCPConnection
        let message = ExternalMsgEncoder.shutdown(name)
        c.writev(message)
      else
        _env.out.print("dagon: don't have a connection to send shutdown to "
          + name)
      end
    else
      _env.out.print("dagon: Failed sending shutdown to " + name)
      transition_to(ErrorShutdown)
    end

  be received_ready(conn: TCPConnection, name: String) =>
    """
    Register the connection for a ready node.
    TODO: If we want to wait for both leaders to be Ready then fixme
    """
    _env.out.print("dagon: received ready from child: " + name)
    try
      let child = roster(name)
      // update child state and connection
      child.state = Ready
      child.conn = conn
    else
      _env.out.print("dagon: failed to find child in roster")
      transition_to(ErrorShutdown)
      return
    end
    // Boot workers and receivers if leader is ready
    if _is_leader(name) then // fixme
      boot_workers_receivers()
    end
    // Verify canary nodes are ready
    verify_senders_ready()

  be received_topology_ready(conn: TCPConnection, name: String) =>
    """
    The leader signaled ready. Boot the canary nodes.
    """
    _env.out.print("dagon: received topology ready from: " + name)
    if _is_leader(name) then
      try
        let child = roster(name)
        // update child state
        child.state = TopologyReady
      else
        _env.out.print("dagon: failed to find leader in roster")
        transition_to(ErrorShutdown)
        return
      end
      transition_to(TopologyReady)
    else
      _env.out.print("dagon: ignoring topology ready from worker node")
    end

  fun ref _is_leader(name: String): Bool =>
    """
    Check if a child is the leader.
    TODO: Find better predicate to decide if child is a leader.
    """
    if (name == "leader") or (name == "initializer") then
      return true
    else
      return false
    end

  fun ref _canary_is_ready(name: String): Bool =>
    """
    Check if a canary processes is ready.
    """
    try
      let child = roster(name)
      let child_state = child.state
      _env.out.print("dagon: " + name + " state: " + child.state.string())
      _env.out.print("dagon: " + name + " iscanary: " + child.is_canary.string())
      if child.is_canary then
        match child_state
        | Ready =>  return true
        end
      end
    else
      _env.out.print("dagon: could not get canary")
      transition_to(ErrorShutdown)
    end
    false

  be start_canary_node(name: String) =>
    """
    Send start to a canary node.
    """
    _env.out.print("dagon: starting canary node: " + name)
    try
      let child = roster(name)
      let canary_conn: (TCPConnection | None) = child.conn
      // send start to canary
      try
        if (child.state isnt Started) and (canary_conn isnt None) then
          send_start(canary_conn as TCPConnection, name)
          child.state = Started
        end
      else
        _env.out.print("dagon: failed sending start to canary node")
        transition_to(ErrorShutdown)
      end
    else
      _env.out.print("dagon: could not get canary node from roster")
      transition_to(ErrorShutdown)
    end

  be send_start(conn: TCPConnection, name: String) =>
    """
    Tell a child to start work.
    """
    _env.out.print("dagon: sending start to child: " + name)
    try
      let c = conn as TCPConnection
      let message = ExternalMsgEncoder.start()
      c.writev(message)
    else
      _env.out.print("dagon: Failed sending start")
      transition_to(ErrorShutdown)
    end

  be received_done(conn: TCPConnection, name: String) =>
    """
    Node is done. Update it's state.
    """
    _env.out.print("dagon: received Done from child: " + name)
    try
      let child = roster(name)
      child.state = Done
    else
      _env.out.print("dagon: failed to set child to done")
      transition_to(ErrorShutdown)
      return
    end
    verify_senders_done()

  be wait_for_processing() =>
    """
    Start the time to wait for processing.
    """
    _env.out.print("dagon: waiting for processing to finish")
    let timer = Timer(WaitForProcessing(_env, this, _timeout), 0, 1_000_000_000)
    _processing_timer = timer
    _timers(consume timer)

  be shutdown_topology() =>
    """
    Wait for n seconds then shut the topology down.
    TODO: Get the value pairs and iterate over those.
    """
    _env.out.print("dagon: shutting down topology")
    let timer = Timer(WaitForShutdown(_env, this), 1_000_000_000, 1_000_000_000)
    _timers(consume timer)
    try
      for key in roster.keys() do
        let child = roster(key)
        if child.state isnt DoneShutdown then send_shutdown(child.name) end
      end
      transition_to(TopologyDoneShutdown)
    else
      _env.out.print("dagon: can't iterate over roster")
      transition_to(ErrorShutdown)
    end

  be handle_shutdown() =>
    """
    Print state of each child in roster.
    TODO: Get the value pairs and iterate over those.
    """
    var num_left: I32 = 0
    try
      for key in roster.keys() do
        let child = roster(key)
        if child.state isnt Done then
          num_left = num_left + 1
          _env.out.print(key + " isn't Done yet")
          if child.state isnt Killed then
            _env.out.print(key + " isn't Killed yet")
            kill_child(child)
          end
        end
      end
      if num_left > 0 then
        _env.out.print("waiting for " + num_left.string() + " children.")
        let timer = Timer(WaitForShutdown(_env, this), 250_000_000, 1_000_000_000)
        _timers(consume timer)
      else
        shutdown_listener()
      end
    else
      _env.out.print("dagon: can't iterate over roster")
      transition_to(ErrorShutdown)
    end

  be received_done_shutdown(conn: TCPConnection, name: String) =>
    """
    Node has shutdown. Remove it from our roster.
    """
    _env.out.print("dagon: received done_shutdown from child: " + name)
    conn.dispose()
    try
      let child = roster(name)
      child.state = DoneShutdown
      if child.is_canary then
        _env.out.print("dagon: canary reported DoneShutdown ---------------------")
      end
    else
      _env.out.print("dagon: failed to set child state to done_shutdown")
      transition_to(ErrorShutdown)
      return
    end
    verify_senders_shutdown()

  fun ref _is_done_shutdown(name: String): Bool =>
    """
    Check if the state of a node is DoneShutdown
    """
    try
      let child = roster(name)
      match child.state
      | DoneShutdown => return true
      else
        return false
      end
    else
      _env.out.print("dagon: could not get state for " + name)
      transition_to(ErrorShutdown)
    end
    false

  be received_exit_code(name: String, exit_code: I32) =>
    """
    Node has exited.
    """
    _env.out.print("dagon: exited child: " + name)
    if _is_leader(name) and _is_done_shutdown(name) then
      shutdown_listener()
    elseif (name == "giles-receiver") and _expect then
      _env.out.print("Expected termination occured for: giles-receiver")
      cancel_timeout_timer()
    end
    try
      let child = roster(name)
      child.state = Done
    end

  be received_start_senders(conn: TCPConnection) =>
    transition_to(StartSenders)
    send_senders_started(conn)

  be transition_to(state': DagonState, node_name: String = "") =>
    var old_state: DagonState
    match (state, state')
    | (Initialized, Booting) =>
      old_state = state = state'
      boot_topology()
    | (Booting, TopologyReady) =>
      old_state = state = state'
      boot_canaries()
    | (TopologyReady, AwaitingSendersReady) =>
      old_state = state = state'
      verify_senders_ready()
    | (AwaitingSendersReady, SendersReady) =>
      old_state = state = state'
      if not _delay_senders then start_canary_nodes() end
    | (SendersReady, StartSenders) =>
      old_state = state = state'
      start_canary_nodes()
    | (StartSenders, SendersStarted) =>
      old_state = state = state'
    | (SendersReady, SendersStarted) =>
      old_state = state = state'
    | (SendersStarted, SendersDone) =>
      old_state = state = state'
    | (SendersStarted, SendersDoneShutdown) =>
      old_state = state = state'
      wait_for_processing()
    | (SendersDone, SendersDoneShutdown) =>
      old_state = state = state'
      wait_for_processing()
    | (SendersDoneShutdown, TopologyDoneShutdown) =>
      old_state = state = state'
      shutdown_topology()
    | (ErrorShutdown, _) =>
      old_state = state
    | (_, ErrorShutdown) =>
      old_state = state = state'
      _env.exitcode(-1)
      shutdown_topology()
    | (_, TopologyDoneShutdown) =>
      old_state = state = state'
    else
      _env.err.print("Unable to transition from state: " + state.string() + " to: " + state'.string())
      transition_to(ErrorShutdown)
      return
    end
    _env.out.print("dagon: transitioned from: " + old_state.string() + " to: " + state'.string())

  be start_canary_nodes() =>
    for node in _canaries.values() do
      start_canary_node(node.name)
    end
    transition_to(SendersStarted)

  be verify_senders_ready() =>
    if state is AwaitingSendersReady then
      for node in _canaries.values() do
        try
          let sender = roster(node.name)
          if sender.state isnt Ready then return end
        else
          return
        end
      end
      transition_to(SendersReady)
    end

  be verify_senders_done() =>
    if state is SendersStarted then
      for node in _canaries.values() do
        try
          let sender = roster(node.name)
          if sender.state isnt Done then break end
        end
        transition_to(SendersDone)
      end
    end

  be verify_senders_shutdown() =>
    if state is SendersStarted then
      for node in _canaries.values() do
        try
          let sender = roster(node.name)
          if sender.state isnt DoneShutdown then return end
        else
          return
        end
      end
      transition_to(SendersDoneShutdown)
    end

  be send_senders_started(conn: TCPConnection) =>
    """
    Tell notifier that senders have been started.
    """
    _env.out.print("dagon: sending 'SendersStarted' to notifier")
    let message = ExternalMsgEncoder.senders_started()
    conn.writev(message)


class ProcessClient is ProcessNotify
  let _env: Env
  let _name: String
  var exit_code: I32 = 0
  let _p_mgr: ProcessManager

  new iso create(env: Env, name: String, p_mgr: ProcessManager) =>
    _env = env
    _name= name
    _p_mgr = p_mgr

  fun ref stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
    let out = String.from_array(consume data)
    _env.out.print("dagon: " + _name + " STDOUT [")
    _env.out.print(out)
    _env.out.print("dagon: " + _name + " STDOUT ]")

  fun ref stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
    let err = String.from_array(consume data)
    _env.out.print("dagon: " + _name + " STDERR [")
    _env.out.print(err)
    _env.out.print("dagon: " + _name + " STDERR ]")

  fun ref failed(process: ProcessMonitor ref, err: ProcessError) =>
    match err
    | ExecveError   => _env.out.print("dagon: ProcessError: ExecveError")
    | PipeError     => _env.out.print("dagon: ProcessError: PipeError")
    | ForkError     => _env.out.print("dagon: ProcessError: ForkError")
    | WaitpidError  => _env.out.print("dagon: ProcessError: WaitpidError")
    | WriteError    => _env.out.print("dagon: ProcessError: WriteError")
    | KillError     => _env.out.print("dagon: ProcessError: KillError")
    | Unsupported   => _env.out.print("dagon: ProcessError: Unsupported")
    else
      _env.out.print("dagon: Unknown ProcessError!")
      _p_mgr.transition_to(ErrorShutdown)
    end

  fun ref dispose(process: ProcessMonitor ref, child_exit_code: I32) =>
    _env.out.print("dagon: " + _name + " exited with exit code: "
      + child_exit_code.string())
    _p_mgr.received_exit_code(_name, child_exit_code)
    if child_exit_code != 0 then
      _p_mgr.transition_to(ErrorShutdown)
    end

class WaitForProcessing is TimerNotify
  let _env: Env
  let _p_mgr: ProcessManager
  let _limit: I64
  var _counter: I64

  new iso create(env: Env, p_mgr: ProcessManager, limit: I64) =>
    _counter = 0
    _env = env
    _p_mgr = p_mgr
    _limit = limit

  fun ref _next(): I64 =>
    _counter = _counter + 1
    _counter

  fun ref apply(timer: Timer, count: U64): Bool =>
    let c = _next()
    _env.out.print("dagon: wait for processing to finish: " + c.string())
    if c > _limit then
      false
    else
      true
    end

  fun ref cancel(timer: Timer) =>
    _p_mgr.shutdown_topology()


class WaitForListener is TimerNotify
  let _env: Env
  let _p_mgr: ProcessManager
  let _limit: I64
  var _counter: I64

  new iso create(env: Env, p_mgr: ProcessManager, limit: I64) =>
    _counter = 0
    _env = env
    _p_mgr = p_mgr
    _limit = limit

  fun ref _next(): I64 =>
    _counter = _counter + 1
    _counter

  fun ref apply(timer: Timer, count: U64): Bool =>
    let c = _next()
    _env.out.print("dagon: waited for listener, trying to boot: " + c.string())
    _p_mgr.boot_topology()
    if c > _limit then
      _env.out.print("dagon: listener timeout reached " + c.string())
      false // we're out of time
    else
      true // wait for next tick
    end

  fun ref cancel(timer: Timer) =>
    _env.out.print("dagon: timer got canceled")

class WaitForShutdown is TimerNotify
  let _env: Env
  let _p_mgr: ProcessManager

  new iso create(env: Env, p_mgr: ProcessManager) =>
    _env = env
    _p_mgr = p_mgr

  fun ref apply(timer: Timer, count: U64): Bool =>
    _env.out.print("dagon: wait for shutdown to finish.")
    _p_mgr.handle_shutdown()
    false

//
// SHUTDOWN GRACEFULLY ON SIGTERM
//

class TermHandler is SignalNotify
  let _p_mgr: ProcessManager

  new iso create(p_mgr: ProcessManager) =>
    _p_mgr = p_mgr

  fun ref apply(count: U32): Bool =>
    _p_mgr.transition_to(ErrorShutdown)
    true

