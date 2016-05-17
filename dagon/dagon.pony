use "assert"
use "collections"
use "files"
use "time"
use "messages"
use "net"
use "options"
use "ini"
use "osc-pony"
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
    var timeout: I64 = 0
    var path: String = ""
    var phone_home: String = ""
    var phone_home_host: String = ""
    var phone_home_service: String = ""
    var service: String = ""
    var options = Options(env)
    options
    .add("timeout", "t", I64Argument)
    .add("filepath", "f", StringArgument)
    .add("phone_home", "h", StringArgument)
    try
      for option in options do
        match option
        | ("timeout", let arg: I64) =>
          if arg < 0 then
            env.out.print("dagon: timeout can't be negative")
            error
          else
            timeout = arg
          end
        | ("filepath", let arg: String) => path = arg
        | ("phone_home", let arg: String) => phone_home = arg
      end
    end
    env.out.print("dagon: timeout: " + timeout.string())
    env.out.print("dagon: path: " + path)
    if phone_home != "" then
      let ph_addr = phone_home.split(":")
      try
        phone_home_host = ph_addr(0)
        phone_home_service = ph_addr(1)
      end
    end
    env.out.print("dagon: host: " + phone_home_host)
    env.out.print("dagon: service: " + phone_home_service)
    ProcessManager(env, timeout, path, phone_home_host, phone_home_service)
  else
    env.out.print("dagon: error parsing commandline args")
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
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let m: ReadyMsg val =>
          _env.out.print("dagon: " + m.node_name + ": Ready")
          _p_mgr.received_ready(conn, m.node_name)
        | let m: TopologyReadyMsg val =>
          _env.out.print("dagon: " + m.node_name + ": TopologyReady")
          _p_mgr.received_topology_ready(conn, m.node_name)          
        | let m: DoneMsg val =>
          _env.out.print("dagon: " + m.node_name + ": Done")
          _p_mgr.received_done(conn, m.node_name)          
        | let m: DoneShutdownMsg val =>
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
  let pm: ProcessMonitor
  var conn: (TCPConnection | None) = None
  var state: ChildState = Booting
  
  new create(name': String, pm': ProcessMonitor) =>
    name = name'
    pm = pm'

    
class Sender
  let node_name: String
  let filepath: FilePath
  let args: Array[String] val
  let vars: Array[String] val
  
  new create(node_name': String, filepath': FilePath,
    args': Array[String] val, vars': Array[String] val)
  =>
    node_name = node_name'
    filepath = filepath'
    args = args'
    vars = vars'

    
actor ProcessManager
  let _env: Env
  let _timeout: I64
  let _path: String
  let _host: String
  let _service: String
  var _sender_node: String = ""
  var _sender: (Sender | None) = None
  var roster: Map[String, Child] = Map[String, Child]
  var _listener: (TCPListener | None) = None
  var _listener_is_ready: Bool = false
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
      let timer = Timer(WaitForListener(_env, this, _timeout), 0, 1_000_000_000)
      _timer = timer
      _timers(consume timer)
    else
      _env.out.print("Failed creating tcp listener")
      return
    end
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
    if _listener_is_ready then
      _env.out.print("dagon: cancelling timer")
      cancel_timer()
      _env.out.print("dagon: listener is ready. Booting topology.")
      parse_and_boot()
    else
      _env.out.print("dagon: listener is not ready.")
    end
    
  be parse_and_boot() =>
    """
    Parse ini file and boot components
    """
    _env.out.print("dagon: parse_and_boot")
    var node_name: String = ""
    var filepath: (FilePath | None) = None
    var is_sender: Bool = false
    try
      let ini_file = File(FilePath(_env.root as AmbientAuth, _path))
      let sections = IniParse(ini_file.lines())
      for section in sections.keys() do
        let args: Array[String] iso = recover Array[String](6) end
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
            args.push("--" + key + "=" + sections(section)(key))
          | "sender" =>
            match sections(section)(key)
            | "true" =>
              is_sender = true
            else
              is_sender = false
            end
          | "leader" =>
            args.push("-l")  
          else
            args.push("--" + key + "=" + sections(section)(key))
          end
        end
        args.push("--phone_home=" + _host + ":" + _service)
        let vars: Array[String] iso = recover Array[String](0) end
        if filepath isnt None then
          match is_sender
          | false =>
            boot_process(node_name, filepath as FilePath,
              consume args, consume vars)
          | true =>
            register_sender(node_name, filepath as FilePath,
              consume args, consume vars)
          end
        end
      end
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

  be register_sender(node_name: String, filepath: FilePath,
    args: Array[String] val, vars: Array[String] val)
  =>
    """
    Register the sender node. We will boot it after the rest of the topology
    is ready.
    TODO: Get rid of _sender_node
    """
    _env.out.print("dagon: registering sender node")
    _sender_node = node_name // refactor this
    // store sender info for later use
    _sender = Sender(node_name, filepath, args, vars)
    
  be boot_process(node_name: String, filepath: FilePath,
    args: Array[String] val, vars: Array[String] val)
  =>
    """
    Start up processes with host and service as phone home address.
    """
    try
      let pn: ProcessNotify iso = ProcessClient(_env, node_name, this)
      let pm: ProcessMonitor = ProcessMonitor(consume pn, filepath,
        consume args, consume vars)
      let child = Child(node_name, pm)
      _env.out.print("dagon: booting: " + node_name)
      roster.insert(node_name, child)
    else
      _env.out.print("dagon: booting process failed")
    end

  be boot_sender_node() =>
    """
    Boot the Sender.
    """
    try
      if _sender isnt None then
        let sender = _sender as Sender
        let node_name = sender.node_name
        let filepath = sender.filepath
        let args = sender.args
        let vars = sender.vars
        boot_process(node_name, filepath, args, vars)
      else
        _env.out.print("dagon: can't boot sender. No registered.")
      end
    else
      _env.out.print("dagon: can't boot sender. No registered.")
    end
    
  be send_shutdown(node_name: String) =>
    """
    Shutdown a running process
    """
    try
      _env.out.print("dagon: sending shutdown to " + node_name)
      let child = roster(node_name)
      if child.conn isnt None then
        let c = child.conn as TCPConnection
        let message = WireMsgEncoder.shutdown(node_name)
        c.write(message)
      else
        _env.out.print("dagon: don't have a connection to send shutdown "
          + node_name)
      end
    else
      _env.out.print("dagon: Failed sending shutdown to " + node_name)
    end
    
  be received_ready(conn: TCPConnection, node_name: String) =>
    """
    Register the connection for a ready node
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
    // Start sender node if it's READY
    if _sender_is_ready() then
      start_sender_node()
    end

  be received_topology_ready(conn: TCPConnection, node_name: String) =>
    """
    Leader signaled he's ready. Boot the Sender.
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
      // time to boot the sender node
      boot_sender_node()
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
    
  fun ref _sender_is_ready(): Bool =>
    """
    Check if the sender processes is ready.
    """
    try
      let child = roster(_sender_node)
      match child.state
      | Ready => return true
      end
    else
      _env.out.print("dagon: could not get sender")
    end      
    false    

  be start_sender_node() =>
    """
    Send start to the sender node.
    """
    _env.out.print("dagon: starting sender node")
    try
      let child = roster(_sender_node)
      let sender_conn: (TCPConnection | None) = child.conn
      // send start to sender
      try
        if (child.state isnt Started) and (sender_conn isnt None) then
          send_start(sender_conn as TCPConnection, _sender_node)
          child.state = Started
        end
      else
        _env.out.print("dagon: failed sending start to sender node")
      end
    else
      _env.out.print("dagon: could not get sender node from roster")
    end
    
  be send_start(conn: TCPConnection, node_name: String) =>
    """
    Tell a child to start work.
    """
    _env.out.print("dagon: sending start to child: " + node_name)
    try
      let c = conn as TCPConnection
      let message = WireMsgEncoder.start()
      c.write(message)
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
    """
    _env.out.print("dagon: received done_shutdown from child: " + node_name)
    conn.dispose()
    try
      let child = roster(node_name)
      child.state = DoneShutdown
      if child.name == _sender_node then
        _env.out.print("dagon: sender reported DoneShutdown ---------------------")
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
