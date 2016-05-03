use "assert"
use "collections"
use "files"
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
  var _listener: (TCPListener | None) = None
  var _path: String = ""
  var _host: String = ""
  var _service: String = ""
  
  new create(env: Env) =>
    _env = env
    var options = Options(env)
    var args = options.remaining()
    options
      .add("filepath", "f", StringArgument)
      .add("host", "h", StringArgument)
      .add("service", "p", StringArgument)
      
    for option in options do
      match option
      | ("filepath", let arg: String) => _path = arg
      | ("host", let arg: String) => _host = arg
      | ("service", let arg: String) => _service = arg
      end
    end  
    _env.out.print("dagon: path: " + _path)
    _env.out.print("dagon: host: " + _host)
    _env.out.print("dagon: service: " + _service)
    let p_mgr = ProcessManager(_env, this)
    let tcp_n = recover Notifier(env, p_mgr) end
    try
      _listener = TCPListener(env.root as AmbientAuth, consume tcp_n,
        _host, _service)
    else
      _env.out.print("Failed creating tcp listener")
    end
    _boot_topology(p_mgr)

    
  fun ref _boot_topology(p_mgr: ProcessManager) =>
    """
    Parse ini file and boot processes
    """
    var node_name = ""
    var filepath: (FilePath | None) = None
    
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
          else
            args.push("--" + key + "=" + sections(section)(key))
          end
        end
        args.push("--phone_home_host=" + _host)
        args.push("--phone_home_service=" + _service)
        let vars: Array[String] iso = recover Array[String](0) end
        if filepath isnt None then
          p_mgr.boot_process(node_name, filepath as FilePath, consume args, consume vars)
        end
      end
    else
      _env.out.print("dagon: Could not create FilePath for ini file")
    end


    
  be shutdown_topology() =>
    """
    Shutdown the topology
    """
    if (_listener isnt None) then
      try
        let l = _listener as TCPListener
        l.dispose()
      else
        _env.out.print("dagon: Could not dispose of listener")
      end
    end
    
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
  let _dagon: Main
  var roster: Map[String, Child] = Map[String, Child]
  var connections: Map[String, TCPConnection] = Map[String, TCPConnection]
  
  new create(env: Env, dagon: Main) =>
    _env = env
    _dagon = dagon

  be boot_process(node_name: String, filepath: FilePath,
    args: Array[String] val, vars: Array[String] val)
    =>
    """
    Start up processes with host and service as phone home address
    """
    _env.out.print("dagon: booting process " + filepath.path)
    try
      let pn: ProcessNotify iso = ProcessClient(_env, node_name, this)
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
    _env.out.print("dagon: received done_shutdown from child: " + node_name)
    try
      // get, close and remove the connection
      let c = connections(node_name)
      c.dispose()
      connections.remove(node_name)
    else
      _env.out.print("dagon: failed to close child connection")
    end
    try
      let child = roster(node_name)
      child.change_state(_DoneShutdown)
    else
      _env.out.print("dagon: failed to set child to done_shutdown")
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
    if roster.size() == 0 then _dagon.shutdown_topology() end
    
class ProcessClient is ProcessNotify
  let _env: Env
  let _node_name: String
  var exit_code: I32 = 0
  let _pm: ProcessManager
  
  new iso create(env: Env, node_name: String, pm: ProcessManager) =>
    _env = env
    _node_name= node_name
    _pm = pm
    
  fun ref stdout(data: Array[U8] iso) =>
    let out = String.from_array(consume data)
    _env.out.print(_node_name + " STDOUT: " + out)

  fun ref stderr(data: Array[U8] iso) =>
    let err = String.from_array(consume data)
    _env.out.print(_node_name + " STDERR: " + err)
    
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
    _pm.received_exit_code(_node_name)
