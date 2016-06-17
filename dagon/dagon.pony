use "assert"
use "collections"
use "files"
use "time"
use "buffy/messages"
use "net"
use "options"
use "ini"
use "process"
use "sendence/tcp"


primitive Booting
primitive Ready
primitive Started
primitive TopologyReady
primitive Done
primitive DoneShutdown

type ChildState is
  ( Booting
  | Ready
  | Started
  | TopologyReady
  | Done
  | DoneShutdown
  )


actor Main
  
  new create(env: Env) =>
    """
    Check if we have all commandline arguments. If no args where
    given run the tests.
    TODO: Run tests if list of args is empty.
    """
    var required_args_are_present = true
    var timeout: (I64 | None) = None
    var path: (String | None) = None
    var p_arg: (Array[String] | None) = None
    var phone_home_host: String = ""
    var phone_home_service: String = ""
    var service: String = ""
    var options = Options(env)
    options
    .add("timeout", "t", I64Argument)
    .add("filepath", "f", StringArgument)
    .add("phone_home", "h", StringArgument)
    for option in options do
      match option
      | ("timeout", let arg: I64) => timeout = arg
      | ("filepath", let arg: String) => path = arg
      | ("phone_home", let arg: String) => p_arg = arg.split(":")
      else
        env.err.print("dagon: unknown argument")
        env.err.print("dagon: usage: --timeout=<seconds>" +
        " --filepath=<path> --phone_home=<host:port>")
      end
    end

    try
      if timeout is None then
        env.err.print("dagon: Must supply required '--timeout' argument")
        required_args_are_present = false
      elseif (timeout as I64) < 0 then
        env.err.print("dagon: timeout can't be negative")
        required_args_are_present = false
      end
    
      if path is None then
        env.err.print("dagon error: Must supply required '--filepath' argument")
        required_args_are_present = false
      end

      if p_arg is None then
        env.err.print("dagon error: Must supply required '--phone_home' argument")
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
      env.out.print("dagon: path: " + (path as String))

      phone_home_host = (p_arg as Array[String])(0)
      phone_home_service = (p_arg as Array[String])(1)

      env.out.print("dagon: host: " + phone_home_host)
      env.out.print("dagon: service: " + phone_home_service)
      ProcessManager(env, timeout as I64, path as String,
        phone_home_host, phone_home_service)
    else
      env.err.print("dagon: error parsing arguments")
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
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("dagon: couldn't listen")
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

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(consume chunked)
        match decoded
        | let m: ExternalReadyMsg val =>
          _env.out.print("dagon: " + m.node_name + ": Ready")
          _p_mgr.received_ready(conn, m.node_name)
        | let m: ExternalTopologyReadyMsg val =>
          _env.out.print("dagon: " + m.node_name + ": TopologyReady")
          _p_mgr.received_topology_ready(conn, m.node_name)          
        | let m: ExternalDoneMsg val =>
          _env.out.print("dagon: " + m.node_name + ": Done")
          _p_mgr.received_done(conn, m.node_name)          
        | let m: ExternalDoneShutdownMsg val =>
          _env.out.print("dagon: " + m.node_name + ": DoneShutdown")
          _p_mgr.received_done_shutdown(conn, m.node_name)
        else
          _env.out.print("dagon: Unexpected message from child")
        end
      else
        _env.out.print("dagon: Unable to decode message from child")
      end
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")

    
class Child
  let name: String
  let is_canary: Bool
  let pm: ProcessMonitor
  var conn: (TCPConnection | None) = None
  var state: ChildState = Booting
  
  new create(name': String, is_canary': Bool, pm': ProcessMonitor) =>
    name = name'
    is_canary = is_canary'
    pm = pm'

    
class Node
  let node_name: String
  let is_canary: Bool
  let is_leader: Bool
  let filepath: FilePath
  let args: Array[String] val
  let vars: Array[String] val
  
  new create(node_name': String,
    is_canary': Bool, is_leader': Bool,
    filepath': FilePath, args': Array[String] val,
    vars': Array[String] val)
  =>
    node_name = node_name'
    is_canary = is_canary'
    is_leader = is_leader'
    filepath = filepath'
    args = args'
    vars = vars'

    
actor ProcessManager
  let _env: Env
  let _timeout: I64
  let _path: String
  let _host: String
  let _service: String
  var _canaries: Map[String, Node val] = Map[String, Node val](2)
  var _workers_receivers: Map[String, Node val] = Map[String, Node val](2)
  var _leaders: Map[String, Node val] = Map[String, Node val](1)
  var roster: Map[String, Child] = Map[String, Child]
  var _listener: (TCPListener | None) = None
  var _listener_is_ready: Bool = false
  var _finished_registration: Bool = false
  let _timers: Timers = Timers
  var _timer: (Timer tag | None) = None
  
  new create(env: Env, timeout: I64, path: String,
    host: String, service: String)
  =>
    _env = env
    _timeout = timeout
    _path = path
    _host = host
    _service = service
    let tcp_n = recover Notifier(env, this) end
    try
      _listener = TCPListener(env.root as AmbientAuth, consume tcp_n,
      host, service)
      let timer = Timer(WaitForListener(_env, this, _timeout), 0, 2_000_000_000)
      _timer = timer
      _timers(consume timer)
    else
      _env.out.print("Failed creating tcp listener")
      return
    end
    parse_and_register()
    boot_topology()
    
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
    if _timer isnt None then
      try
        let t = _timer as Timer tag
        _timers.cancel(t)
        _env.out.print("dagon: canceled listener timer")
      else
        _env.out.print("dagon: can't cancel listener timer")
      end
    else
      _env.out.print("dagon: no listener to cancel")
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
    
  be parse_and_register() =>
    """
    Parse ini file and register components.
    """
    _env.out.print("dagon: parse_and_register")
    var node_name: String = ""
    var filepath: (FilePath | None) = None
    var is_canary: Bool = false
    var is_leader: Bool = false
    try
      let ini_file = File(FilePath(_env.root as AmbientAuth, _path))
      let sections = IniParse(ini_file.lines())
      for section in sections.keys() do
        let argsbuilder: Array[String] iso = recover Array[String](6) end
        node_name = ""
        filepath = None
        is_canary = false
        is_leader = false
        for key in sections(section).keys() do
          match key
          | "path" =>
            try
              filepath = FilePath(_env.root as AmbientAuth,
                sections(section)(key))
            else
              _env.out.print("dagon: Could not create FilePath")
            end
          | "name" =>
            node_name = sections(section)(key)
            argsbuilder.push("--" + key + "=" + sections(section)(key))
          | "sender" => // fixme
            match sections(section)(key)
            | "true" =>
              is_canary = true
            else
              is_canary = false
            end
            | "leader" => // fixme
              match sections(section)(key)
              | "true" =>
                is_leader = true
                argsbuilder.push("-l")  
              else
                is_leader = false
              end
          else
            argsbuilder.push("--" + key + "=" + sections(section)(key))
          end
        end
        argsbuilder.push("--phone_home=" + _host + ":" + _service)

        let a: Array[String] val = consume argsbuilder

        // for s in a.values() do
        //   _env.out.print("dagon: args value: " + s)
        // end
        
        let vars: Array[String] iso = recover Array[String](0) end
        if filepath isnt None then          
          register_node(node_name, is_canary, is_leader,
            filepath as FilePath, a, consume vars)          
        else
          _env.out.print("dagon: filepath not valid for: " + node_name)
        end
      end
      _env.out.print("dagon: finished registration of nodes")
      _finished_registration = true
    else
      _env.out.print("dagon: Could not create FilePath for ini file")
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

  be register_node(node_name: String,
    is_canary: Bool, is_leader: Bool,
    filepath: FilePath, args: Array[String] val,
    vars: Array[String] val)
  =>
    """
    Register a node with the appropriate map.
    """
    if is_canary then
      _env.out.print("dagon: registering canary node: " + node_name)
      _canaries(node_name) = recover Node(node_name, is_canary, is_leader,
        filepath, args, vars) end
    elseif is_leader then
      _env.out.print("dagon: registering leader node: " + node_name)
      _leaders(node_name) = recover Node(node_name, is_canary, is_leader,
        filepath, args, vars) end
    else
      _env.out.print("dagon: registering node: " + node_name)        
      _workers_receivers(node_name) = recover Node(node_name, is_canary, is_leader,
        filepath, args, vars) end
    end

  be boot_leaders() =>
    """
    Boot the leader node.
    """
    for node in _leaders.values() do
      boot_process(node)
    end

  be boot_workers_receivers() =>
    """
    Boot the leader node.
    """
    for node in _workers_receivers.values() do
      boot_process(node)
    end    

  be boot_canaries() =>
    """
    Boot the canary nodes.
    """
    _env.out.print("dagon: booting canary nodes")
    for node in _canaries.values() do
      let node_name = node.node_name
      let filepath = node.filepath
      let args = node.args
      let vars = node.vars
      _env.out.print("dagon: booting canary: " + node_name)
      boot_process(node)
    end
    
  be boot_process(node: Node val)
  =>
    """
    Boot a node as a process.
    """
    _env.out.print("dagon: booting: " + node.node_name)
    let final_args = _prepend_node_name(node.node_name, node.args)
    let final_vars = node.args
    for arg in final_args.values() do
      _env.out.print("dagon: " + node.node_name + " arg: " + arg)
    end
    
    try
      let pn: ProcessNotify iso = ProcessClient(_env, node.node_name, this)
      let pm: ProcessMonitor = ProcessMonitor(consume pn, node.filepath,
        consume final_args, consume final_vars)
      let child = Child(node.node_name, node.is_canary, pm)      
      roster.insert(node.node_name, child)
    else
      _env.out.print("dagon: booting process failed")
    end

  fun ref _prepend_node_name(node_name: String,
    args: Array[String] val): Array[String] val
  =>
    let result: Array[String] iso = recover Array[String](7) end
    result.push(node_name)
    for arg in args.values() do
      result.push(arg)
    end
    result

  be send_shutdown(node_name: String) =>
    """
    Shutdown a running process
    """
    try
      _env.out.print("dagon: sending shutdown to " + node_name)
      let child = roster(node_name)
      if child.conn isnt None then
        let c = child.conn as TCPConnection
        let message = ExternalMsgEncoder.shutdown(node_name)
        c.writev(message)
      else
        _env.out.print("dagon: don't have a connection to send shutdown to "
          + node_name)
      end
    else
      _env.out.print("dagon: Failed sending shutdown to " + node_name)
    end
    
  be received_ready(conn: TCPConnection, node_name: String) =>
    """
    Register the connection for a ready node.
    TODO: If we want to wait for both leaders to be Ready then fixme
    """
    _env.out.print("dagon: received ready from child: " + node_name)
    try
      let child = roster(node_name)
      // update child state and connection
      child.state = Ready
      child.conn  = conn
    else
      _env.out.print("dagon: failed to find child in roster")
    end
    // Boot workers and receivers if leader is ready
    if _is_leader(node_name) then // fixme
      boot_workers_receivers() 
    end
    // Start canary node if it's READY
    if _canary_is_ready(node_name) then
      start_canary_node(node_name)
    end

  be received_topology_ready(conn: TCPConnection, node_name: String) =>
    """
    The leader signaled ready. Boot the canary nodes.
    """
    _env.out.print("dagon: received topology ready from: " + node_name)
    if _is_leader(node_name) then
      try      
        let child = roster(node_name)
        // update child state
        child.state = TopologyReady
      else
        _env.out.print("dagon: failed to find leader in roster")
      end
      boot_canaries()
    else
      _env.out.print("dagon: ignoring topology ready from worker node")
    end
      
  fun ref _is_leader(node_name: String): Bool =>
    """
    Check if a child is the leader.
    TODO: Find better predicate to decide if child is a leader.
    """
    if node_name == "leader" then
      return true
    else
      return false
    end
    
  fun ref _canary_is_ready(node_name: String): Bool =>
    """
    Check if a canary processes is ready.
    """
    try
      let child = roster(node_name)
      let state = child.state
      _env.out.print("dagon: " + node_name + " state: " + _print_state(child))
      _env.out.print("dagon: " + node_name + " iscanary: " + child.is_canary.string())
      // _env.out.print("dagon: iscanary:" + child.is_canary.string())
      if child.is_canary then
        match state
        | Ready =>  return true
        end
      end
    else
      _env.out.print("dagon: could not get canary")
    end      
    false

  fun ref _print_state(child: Child): String =>
    """
    Print the state to stdout.
    """
    match child.state 
    | Booting        => return "Booting"
    | Ready          => return "Ready"
    | Started        => return "Started"
    | TopologyReady  => return "TopologyReady"
    | Done           => return "Done"
    | DoneShutdown   => return "DoneShutdown"
    end
    ""
  
  be start_canary_node(node_name: String) =>
    """
    Send start to a canary node.
    """
    _env.out.print("dagon: starting canary node: " + node_name)
    try
      let child = roster(node_name)
      let canary_conn: (TCPConnection | None) = child.conn
      // send start to canary
      try
        if (child.state isnt Started) and (canary_conn isnt None) then
          send_start(canary_conn as TCPConnection, node_name)
          child.state = Started
        end
      else
        _env.out.print("dagon: failed sending start to canary node")
      end
    else
      _env.out.print("dagon: could not get canary node from roster")
    end
    
  be send_start(conn: TCPConnection, node_name: String) =>
    """
    Tell a child to start work.
    """
    _env.out.print("dagon: sending start to child: " + node_name)
    try
      let c = conn as TCPConnection
      let message = ExternalMsgEncoder.start()
      c.writev(message)
    else
      _env.out.print("dagon: Failed sending start")
    end

  be received_done(conn: TCPConnection, node_name: String) =>
    """
    Node is done. Update it's state.
    """
    _env.out.print("dagon: received Done from child: " + node_name)
    try
      let child = roster(node_name)
      child.state = Done
    else
      _env.out.print("dagon: failed to set child to done")
    end

  be wait_for_processing() =>
    """
    Start the time to wait for processing.
    """
    _env.out.print("dagon: waiting for processing to finish")
    let timers = Timers
    let timer = Timer(WaitForProcessing(_env, this, _timeout), 0, 1_000_000_000)
    timers(consume timer)
    
  be shutdown_topology() =>
    """
    Wait for n seconds then shut the topology down.
    TODO: Get the value pairs and iterate over those.
    """
    _env.out.print("dagon: shutting down topology")
    try
      for key in roster.keys() do
        let child = roster(key)
        send_shutdown(child.name)
      end
    else
      _env.out.print("dagon: can't iterate over roster")
    end

  be received_done_shutdown(conn: TCPConnection, node_name: String) =>
    """
    Node has shutdown. Remove it from our roster.
    TODO: Only enter wait_for_processing once ALL canaries reported DoneShutdown
    """
    _env.out.print("dagon: received done_shutdown from child: " + node_name)
    conn.dispose()
    try
      let child = roster(node_name)
      child.state = DoneShutdown
      if child.is_canary then
        _env.out.print("dagon: canary reported DoneShutdown ---------------------")
        wait_for_processing()
      end      
    else
      _env.out.print("dagon: failed to set child state to done_shutdown")
    end

  fun ref _is_done_shutdown(node_name: String): Bool =>
    """
    Check if the state of a node is DoneShutdown
    """
    try
      let child = roster(node_name)
      match child.state
      | DoneShutdown => return true
      else
        return false
      end
    else
      _env.out.print("dagon: could not get state for " + node_name)
    end
    false
    
  be received_exit_code(node_name: String) =>
    """
    Node has exited.
    """
    _env.out.print("dagon: exited child: " + node_name)
    if _is_leader(node_name) and _is_done_shutdown(node_name) then
      shutdown_listener()
    end

      
class ProcessClient is ProcessNotify
  let _env: Env
  let _node_name: String
  var exit_code: I32 = 0
  let _p_mgr: ProcessManager
  
  new iso create(env: Env, node_name: String, p_mgr: ProcessManager) =>
    _env = env
    _node_name= node_name
    _p_mgr = p_mgr
    
  fun ref stdout(data: Array[U8] iso) =>
    let out = String.from_array(consume data)
    _env.out.print("dagon: " + _node_name + " STDOUT [")
    _env.out.print(out)
    _env.out.print("dagon: " + _node_name + " STDOUT ]")

  fun ref stderr(data: Array[U8] iso) =>
    let err = String.from_array(consume data)
    _env.out.print("dagon: " + _node_name + " STDERR [")
    _env.out.print(err)
    _env.out.print("dagon: " + _node_name + " STDERR ]")
    
  fun ref failed(err: ProcessError) =>
    match err
    | ExecveError   => _env.out.print("dagon: ProcessError: ExecveError")
    | PipeError     => _env.out.print("dagon: ProcessError: PipeError")
    | Dup2Error     => _env.out.print("dagon: ProcessError: Dup2Error")
    | ForkError     => _env.out.print("dagon: ProcessError: ForkError")
    | FcntlError    => _env.out.print("dagon: ProcessError: FcntlError")
    | WaitpidError  => _env.out.print("dagon: ProcessError: WaitpidError")
    | CloseError    => _env.out.print("dagon: ProcessError: CloseError")
    | ReadError     => _env.out.print("dagon: ProcessError: ReadError")
    | WriteError    => _env.out.print("dagon: ProcessError: WriteError")
    | KillError     => _env.out.print("dagon: ProcessError: KillError")
    | Unsupported   => _env.out.print("dagon: ProcessError: Unsupported") 
    else
      _env.out.print("dagon: Unknown ProcessError!")
    end
    
  fun ref dispose(child_exit_code: I32) =>
    _env.out.print("dagon: " + _node_name + " exited with exit code: "
      + child_exit_code.string())
    _p_mgr.received_exit_code(_node_name)

 
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
