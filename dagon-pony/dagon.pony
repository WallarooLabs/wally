use "assert"
use "collections"
use "files"
use "messages"
use "net"
use "options"
use "osc-pony"
use "process"
use "sendence/tcp"
use "time" // testing only; remove once done


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
    var options = Options(env)
    var args = options.remaining()

    options
      .add("filepath", "f", StringArgument)
      .add("name", "n", StringArgument)
      .add("host", "h", StringArgument)
      .add("service", "p", StringArgument)

    var path: String = ""
    var node_name: String = ""
    var host: String = ""
    var service: String = ""
      
    for option in options do
      match option
      | ("filepath", let arg: String) => path = arg
      | ("name", let arg: String) => node_name = arg
      | ("host", let arg: String) => host = arg
      | ("service", let arg: String) => service = arg
      end
    end  

    _env.out.print("dagon: path: " + path)
    _env.out.print("dagon: name: " + node_name)
    _env.out.print("dagon: host: " + host)
    _env.out.print("dagon: service: " + service)

    let p_mgr = ProcessManager(_env)
    let tcp_n = recover Notifier(env, p_mgr) end
    try
      let listener = TCPListener(env.root as AmbientAuth, consume tcp_n,
        host, service)
      _boot_topology(p_mgr, path, node_name, host, service)
      // _shutdown_topology(p_mgr, node_name)  
    else
      _env.out.print("Failed creating tcp listener")
    end

  fun ref _boot_topology(p_mgr: ProcessManager, path: String,
    node_name: String, host: String, service: String)
    =>
    """
    Boot the topology
    """
    try
      let filepath = FilePath(_env.root as AmbientAuth, path)
      let args: Array[String] iso = recover Array[String](6) end
      args.push("-n")
      args.push(node_name)
      args.push("-h")
      args.push(host)
      args.push("-p")
      args.push(service)
      let vars: Array[String] iso = recover Array[String](0) end
      p_mgr.boot_process(node_name, filepath, consume args, consume vars)
    else
      _env.out.print("dagon: Could not boot topology")
    end
    
  fun ref _shutdown_topology(p_mgr: ProcessManager, node_name: String) =>
    """
    Shutdown the topology
    """
    // p_mgr.shutdown_process(node_name)
      
    
class Notifier is TCPListenNotify
  let _env: Env
  let _p_mgr: ProcessManager
  
  new create(env: Env, p_mgr: ProcessManager)
    =>
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
    _env.out.print("dagon: received")
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let m: ReadyMsg val =>
          _env.out.print("dagon: ready node_name: " + m.node_name)
          _p_mgr.received_ready(conn, m.node_name)
        | let m: DoneShutdownMsg val =>
          _env.out.print("dagon: done_shutdown node_name: " + m.node_name)
          _p_mgr.received_done_shutdown(conn, m.node_name)
        else
          _env.out.print("Unexpected message from Child")
        end
      else
        _env.out.print("Unable to decode message from Child")
      end
    end


  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")

class Child
  let name: String
  let pm: ProcessMonitor
  var state: ChildState
  
  new create(name': String, pm': ProcessMonitor) =>
    name = name'
    pm = pm'
    state = _Booting

  fun ref change_state(state': ChildState) =>
    state = state'

actor ProcessManager
  let _env: Env
  var roster: Map[String, Child] = Map[String, Child]
  var connections: Map[String, TCPConnection] = Map[String, TCPConnection]
  
  new create(env: Env) =>
    _env = env

  be boot_process(node_name: String, filepath: FilePath,
    args: Array[String] val, vars: Array[String] val)
    =>
    """
    Start up processes with host and service as phone home address
    """
    _env.out.print("dagon: booting process " + filepath.path)
    try
      let pn: ProcessNotify iso = ProcessClient(_env)
      let pm: ProcessMonitor = ProcessMonitor(consume pn, filepath,
        consume args, consume vars)
      let child = Child(node_name, pm)
      _env.out.print("dagon: roster.size:" + roster.size().string())
      _env.out.print("dagon: inserting into roster: " + node_name)
      roster.insert(node_name, child)
      _env.out.print("dagon: roster.size:" + roster.size().string())
    else
      _env.out.print("dagon: booting process failed")
    end

  be shutdown_process(node_name: String) =>
    """
    Shutdown a running process
    """
    try
      _env.out.print("dagon: sending shutdown...")
      let c = connections(node_name)
      let message = WireMsgEncoder.shutdown(node_name)
      c.write(message)
    else
      _env.out.print("dagon: Failed sending shutdown")
    end
    
  be received_ready(conn: TCPConnection, node_name: String) =>
    """
    Register the connection for a ready node
    """
    _env.out.print("dagon: received ready from child")
    _env.out.print("dagon: node_name: " + node_name)
    try
      // lookup child by name in roster
      let child = roster(node_name)
      // update child state
      child.change_state(_Ready)
      roster.insert(node_name, child)
      // insert connection using name as key
      connections.insert(node_name, conn)
    else
      _env.out.print("dagon: failed to get child from roster")
    end
    // testing - shutdown ready process
    shutdown_process(node_name)

  be received_done_shutdown(conn: TCPConnection, node_name: String) =>
    """
    Node has shutdown. Remove it from our roster.
    """
    _env.out.print("dagon: received done_shutdown from child")
    _env.out.print("dagon: node_name: " + node_name)
    try
      // get and close the connection
      let c = connections(node_name)
      c.dispose()
    else
      _env.out.print("dagon: failed to close child connection")
    end
    try
      // remove child from roster
      connections.remove(node_name)
    else
      _env.out.print("dagon: failed to remove child from roster")
    end


    
class ProcessClient is ProcessNotify
  let _env: Env
  var exit_code: I32 = 0
  
  new iso create(env: Env) =>
    _env = env
    
  fun ref stdout(data: Array[U8] iso) =>
    let out = String.from_array(consume data)
    _env.out.print("STDOUT: " + out)

  fun ref stderr(data: Array[U8] iso) =>
    let err = String.from_array(consume data)
    _env.out.print("STDERR: " + err)
    
  fun ref failed(err: ProcessError) =>
    match err
    | ExecveError   => _env.out.print("ProcessError: ExecveError")
    | PipeError     => _env.out.print("ProcessError: PipeError")
    | Dup2Error     => _env.out.print("ProcessError: Dup2Error")
    | ForkError     => _env.out.print("ProcessError: ForkError")
    | FcntlError    => _env.out.print("ProcessError: FcntlError")
    | WaitpidError  => _env.out.print("ProcessError: WaitpidError")
    | CloseError    => _env.out.print("ProcessError: CloseError")
    | ReadError     => _env.out.print("ProcessError: ReadError")
    | WriteError    => _env.out.print("ProcessError: WriteError")
    | KillError     => _env.out.print("ProcessError: KillError")
    | Unsupported   => _env.out.print("ProcessError: Unsupported") 
    else
      _env.out.print("Unknown ProcessError!")
    end
    
  fun ref dispose(child_exit_code: I32) =>
    exit_code = consume child_exit_code
    _env.out.print("Child exit code: " + exit_code.string())
