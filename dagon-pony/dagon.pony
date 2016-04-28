use "net"
use "collections"
use "options"
use "assert"
use "process"
use "osc-pony"

use "../buffy-pony/messages"

primitive _ready
primitive _done
primitive _done_shutdown

type ChildState is
  ( _booting,
  | _ready,
  | _done,
  | _done_shutdown
  )


actor Main
  new create(env: Env) =>
    var options = Options(env)
    var args = options.remaining()
  
    try
      let buffy_name: String val = args(1).clone()
      let sender_name: String val = args(2).clone()
      let receiver_name: String val = args(3).clone()
      let process_names: Array[String val] val = recover val [buffy_name,
        sender_name, receiver_name] end
      TCPListener(env.root as AmbientAuth, recover Notifier(env, process_names) end)
    else
      env.out.print("Parameters: buffy_binary giles_sender_binary giles_receiver_binary")
    end

class Child
  let _name: String
  let _pm: ProcessMonitor
  let _pn: ProcessClient
  var state: ChildState
  
  new create(name: String, pm: ProcessMonitor, pn: ProcessClient) =>
    _name = name
    _pm = pm
    _pn = pn
    state = _booting

  fun ref change_state(state': ChildState) =>
    state = state


class Notifier is TCPListenNotify
  let _env: Env
  let _process_manager: ProcessManager
  var _host: String = "127.0.0.1"
  var _service: String = "8080"

  new create(env: Env, process_names: Array[String val] val) =>
    _env = env
    _process_manager = ProcessManager(_env, process_names)

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _process_manager.initiate_processes(_host, _service)
      _env.out.print("dagon: listening on " + _host + ":" + _service)
    else
      _env.out.print("dagon: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("dagon: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ConnectNotify(_env, _process_manager)

    
class ConnectNotify is TCPConnectionNotify
  let _env: Env
  let _process_manager: ProcessManager

  new iso create(env: Env, process_manager: ProcessManager) =>
    _env = env
    _process_manager = process_manager

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    // Do something with data
    // If it's a process ack:
    //    _process_manager.ack_startup(process_name, data)
    _env.out.print("dagon: received")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")


actor ProcessManager
  let _env: Env
  var _host: String = ""
  var _service: String = ""
  var children = Array[Child]
  
  new create(env: Env, process_names: Array[String val] val) =>
    _env = env
    try
      _buffy_name = process_names(0)
      _sender_name = process_names(1)
      _receiver_name = process_names(2)
    else
      _env.out.print("dagon: couldn't get process names")
    end

  be initiate_processes(host: String, service: String) =>
    _host = host
    _service = service
    // Start up processes with host and service as phone home address
    _env.out.print("dagon: began process startup")

  be ack_startup(process_name: String) =>
    // Do something with acks
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
