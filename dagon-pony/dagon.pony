use "net"
use "collections"
use "options"
use "assert"

actor Main
  new create(env: Env) =>
    var options = Options(env)
    var args = options.remaining()

    try
      let buffy_name: String val = args(1).clone()
      let sender_name: String val = args(2).clone()
      let receiver_name: String val = args(3).clone()
      let process_names: Array[String val] val = recover val [buffy_name, sender_name, receiver_name] end
      TCPListener(recover Notifier(env, process_names) end)
    else
      env.out.print("Parameters: buffy_binary giles_sender_binary giles_receiver_binary")
    end

class Notifier is TCPListenNotify
  let _env: Env
  let _process_manager: ProcessManager
  var _host: String = ""
  var _service: String = ""

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
  var _buffy_name: String val = ""
  var _sender_name: String val = ""
  var _receiver_name: String val = ""
  var _host: String = ""
  var _service: String = ""

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

