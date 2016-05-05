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


primitive _Booting
primitive _Ready
primitive _Done
primitive _DoneShutdown

type ChildState is
  ( _Booting
  | _Ready
  | _Done
  | _DoneShutdown
  )


actor Main
  let _env: Env
  
  new create(env: Env) =>
    _env = env
    var path: String = ""
    var host: String = ""
    var service: String = ""
    var options = Options(env)
    var args = options.remaining()
    options
      .add("filepath", "f", StringArgument)
      .add("host", "h", StringArgument)
      .add("service", "p", StringArgument)
    for option in options do
      match option
      | ("filepath", let arg: String) => path = arg
      | ("host", let arg: String) => host = arg
      | ("service", let arg: String) => service = arg
      end
    end  
    _env.out.print("dagon: path: " + path)
    _env.out.print("dagon: host: " + host)
    _env.out.print("dagon: service: " + service)
    let p_mgr = ProcessManager(_env, path, host, service)
    

    
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
    else
      _env.out.print("dagon: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("dagon: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ConnectNotify(_env, _p_mgr) // store this with the child

    
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
          _env.out.print("dagon: " + m.node_name + ": _Ready")
          _p_mgr.received_ready(conn, m.node_name)
        | let m: DoneMsg val =>
          _env.out.print("dagon: " + m.node_name + ": _Done")
          _p_mgr.received_done(conn, m.node_name)          
        | let m: DoneShutdownMsg val =>
          _env.out.print("dagon: " + m.node_name + ": _DoneShutdown")
          _p_mgr.received_done_shutdown(conn, m.node_name)
        else
          _env.out.print("dagon: Unexpected message from Child")
        end
      else
        _env.out.print("dagon: Unable to decode message from Child")
      end
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")

    
class Child
  let name: String
  let is_canary: Bool
  let pm: ProcessMonitor
  var conn: (TCPConnection | None) = None
  var state: ChildState = _Booting
  
  new create(name': String, is_canary': Bool, pm': ProcessMonitor) =>
    name = name'
    is_canary = is_canary'
    pm = pm'

    
actor ProcessManager
  let _env: Env
  let _path: String
  let _host: String
  let _service: String
  var roster: Map[String, Child] = Map[String, Child]
  var _listener: (TCPListener | None) = None

  new create(env: Env, path: String, host: String, service: String) =>
    _env = env
    _path = path
    _host = host
    _service = service
    let tcp_n = recover Notifier(env, this) end
    try
      _listener = TCPListener(env.root as AmbientAuth, consume tcp_n, host, service)
    else
      _env.out.print("Failed creating tcp listener")
      return
    end
    boot_topology()

  be boot_topology() =>
    """
    Parse ini file and boot processes
    """
    var node_name: String = ""
    var filepath: (FilePath | None) = None
    var is_canary: Bool = false
    try
      let ini_file = File(FilePath(_env.root as AmbientAuth, _path))
      let sections = IniParse(ini_file.lines())
      for section in sections.keys() do
        _env.out.print("Section name is: " + section)
        let args: Array[String] iso = recover Array[String](6) end
        for key in sections(section).keys() do
          _env.out.print(key + " = " + sections(section)(key))
          match key
          | "path" =>
            try
              filepath = FilePath(_env.root as AmbientAuth, sections(section)(key))
            else
              _env.out.print("dagon: Could not create FilePath")
            end
          | "node_name" =>
            node_name = sections(section)(key)
            args.push("--" + key + "=" + sections(section)(key))
          | "canary" =>
            match sections(section)(key)
            | "true" => is_canary = true
            else
              is_canary = false
            end
          else
            args.push("--" + key + "=" + sections(section)(key))
          end
        end
        args.push("--phone_home_host=" + _host)
        args.push("--phone_home_service=" + _service)
        let vars: Array[String] iso = recover Array[String](0) end
        if filepath isnt None then
          boot_process(node_name, is_canary, filepath as FilePath, consume args, consume vars)
        end
      end
    else
      _env.out.print("dagon: Could not create FilePath for ini file")
    end
    
  be shutdown_listener() =>
    """
    Shutdown the listener
    """
    if (_listener isnt None) then
      try
        let l = _listener as TCPListener
        l.dispose()
      else
        _env.out.print("dagon: Could not dispose of listener")
      end
    end    
    
  be boot_process(node_name: String, is_canary: Bool, filepath: FilePath,
    args: Array[String] val, vars: Array[String] val)
    =>
    """
    Start up processes with host and service as phone home address
    """
    _env.out.print("dagon: booting " + node_name + " is_canary: " + is_canary.string())
    try
      let pn: ProcessNotify iso = ProcessClient(_env, node_name, this)
      let pm: ProcessMonitor = ProcessMonitor(consume pn, filepath,
        consume args, consume vars)
      let child = Child(node_name, is_canary, pm)
      _env.out.print("dagon: roster.size:" + roster.size().string())
      _env.out.print("dagon: inserting into roster: " + node_name)
      roster.insert(node_name, child)
      _env.out.print("dagon: roster.size:" + roster.size().string())
    else
      _env.out.print("dagon: booting process failed")
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
        _env.out.print("dagon: don't have a connection to send shutdown")
      end
    else
      _env.out.print("dagon: Failed sending shutdown")
    end
    
  be received_ready(conn: TCPConnection, node_name: String) =>
    """
    Register the connection for a ready node
    """
    _env.out.print("dagon: received ready from child: " + node_name)
    try
      let child = roster(node_name)
      // update child state and connection
      child.state = _Ready
      child.conn  = conn
    else
      _env.out.print("dagon: failed to find child in roster")
    end
    // check if we're ready
    are_we_ready_yet()

  be are_we_ready_yet() =>
    """
    Check if all nodes have reported in as "ready". If so send
    a start to the canary.
    """
    _env.out.print("dagon: are we ready yet?")
    var ready: Bool = true
    var canary_node: String = ""
    var canary_conn: (TCPConnection | None) = None
    try
      for key in roster.keys() do
        let child = roster(key)
        match child.state
        | _Booting => ready = false
        end
        match child.is_canary
        | true  =>
          canary_node = child.name
          canary_conn = child.conn
        end
      end
    else
      _env.out.print("dagon: can't iterate over roster")
    end    
    // send start to canary
    try
      if ready and (canary_conn isnt None) then
        _env.out.print("dagon: we are ready, sending start to canary node")
        send_start(canary_conn as TCPConnection, canary_node)
      end
    else
      _env.out.print("dagon: failed sending start to canary node")
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
    _env.out.print("dagon: received done from child: " + node_name)
    try
      let child = roster(node_name)
      child.state = _Done
      if child.is_canary then
        _env.out.print("dagon: canary is done ---------------------")
        wait_for_processing()
      end
    else
      _env.out.print("dagon: failed to set child to done")
    end

  be wait_for_processing() =>
    """
    Start the time to wait for processing.
    """
    _env.out.print("dagon: waiting for processing to finish")
    let timers = Timers
    let timer = Timer(WaitForProcessing(_env, this, 10), 0, 1_000_000_000)
    timers(consume timer)
    
  be shutdown_topology() =>
    """
    Wait for n seconds then shut the topology down.
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
      child.state = _DoneShutdown
    else
      _env.out.print("dagon: failed to set child state to done_shutdown")
    end

  be received_exit_code(node_name: String) =>
    """
    Node has exited.
    """
    _env.out.print("dagon: exited child: " + node_name)
    try
      roster.remove(node_name)
    else
      _env.out.print("dagon: failed to remove child from roster")
    end
    if roster.size() == 0 then shutdown_listener() end

      
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
    _env.out.print("dagon: " + _node_name + " STDOUT: " + out)

  fun ref stderr(data: Array[U8] iso) =>
    let err = String.from_array(consume data)
    _env.out.print("dagon: " + _node_name + " STDERR: " + err)
    
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
    exit_code = consume child_exit_code
    _env.out.print("dagon: Child exit code: " + exit_code.string())
    _p_mgr.received_exit_code(_node_name)

 
class WaitForProcessing is TimerNotify  
  let _env: Env
  let _p_mgr: ProcessManager
  let _limit: U64
  var _counter: U64
  
  new iso create(env: Env, p_mgr: ProcessManager, limit: U64) =>
    _counter = 0
    _env = env
    _p_mgr = p_mgr
    _limit = limit

  fun ref _next(): U64 =>
    _counter = _counter + 1
    _counter
    
  fun ref apply(timer: Timer, count: U64): Bool =>
    let c = _next()
    _env.out.print("dagon: waiting for shutdown " + c.string())
    if c > _limit then
      false
    else
      true
    end
    
  fun ref cancel(timer: Timer) =>
    _p_mgr.shutdown_topology()
