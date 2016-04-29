use "assert"
use "collections"
use "files"
use "messages"
use "net"
use "options"
use "osc-pony"
use "process"

primitive _Booting
primitive _Ready
primitive _Done
primitive _Shutdown

type ChildState is
  ( _Booting
  | _Ready
  | _Done
  | _Shutdown
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
    var name: String = ""
    var host: String = ""
    var service: String = ""
      
    for option in options do
      match option
      | ("filepath", let arg: String) => path = arg
      | ("name", let arg: String) => name = arg
      | ("host", let arg: String) => host = arg
      | ("service", let arg: String) => service = arg
      end
    end  

    _env.out.print("dagon: path: " + path)
    _env.out.print("dagon: name: " + name)
    _env.out.print("dagon: host: " + host)
    _env.out.print("dagon: service: " + service)

    let p_mgr = ProcessManager(_env)

    try
      let listener = TCPListener(env.root as AmbientAuth,
        recover Notifier(env, p_mgr, host, service) end)
      _boot_topology(p_mgr, path, name, host, service)
    else
      _env.out.print("Failed creating tcp listener")
    end

  fun ref _boot_topology(p_mgr: ProcessManager, path: String, name: String,
    host: String, service: String)
    =>
    """
    Boot the topology
    """
    try
      let filepath = FilePath(_env.root as AmbientAuth, path)
      let args: Array[String] iso = recover Array[String](6) end
      args.push("-n")
      args.push(name)
      args.push("-h")
      args.push(host)
      args.push("-p")
      args.push(service)
      let vars: Array[String] iso = recover Array[String](0) end
      
      p_mgr.boot_process(filepath, consume args, consume vars)
    else
      _env.out.print("dagon: Could not boot topology")
    end
    


class Notifier is TCPListenNotify
  let _env: Env
  let _p_mgr: ProcessManager
  let _host: String
  let _service: String

  new create(env: Env, p_mgr: ProcessManager, host: String, service: String)
    =>
    _env = env
    _p_mgr = p_mgr
    _host = host
    _service = service

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print("dagon: listening on " + _host + ":" + _service)
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

  new iso create(env: Env, p_mgr: ProcessManager) =>
    _env = env
    _p_mgr = p_mgr

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    //    _p_mgr.ack_startup(process_name, data)
    _env.out.print("dagon: received")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")

class Child
  let _name: String
  let _pm: ProcessMonitor
  var _state: ChildState
  
  new create(name: String, pm: ProcessMonitor) =>
    _name = name
    _pm = pm
    _state = _Booting

  fun ref change_state(state: ChildState) =>
    _state = state

actor ProcessManager
  let _env: Env
  var children : Array[Child] = Array[Child](1)
  var _buffy_name: String = ""
  var _sender_name: String = ""
  var _receiver_name: String = ""
  
  new create(env: Env) =>
    _env = env

  be boot_process(filepath: FilePath, args: Array[String] val,
    vars: Array[String] val)
    =>
    """
    Start up processes with host and service as phone home address
    """
    _env.out.print("dagon: starting process " + filepath.path)
    try
      let name: String = args(0)
      let pn: ProcessNotify iso = ProcessClient(_env)
      let pm: ProcessMonitor = ProcessMonitor(consume pn, filepath,
        consume args, consume vars)
      let child = Child(name, pm)
      children.push(child)
    else
      _env.out.print("dagon: booting process failed")
    end

  be ack_startup(process_name: String) =>
    """
    Do something with acks
    """
    _env.out.print("dagon: received ack")


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
