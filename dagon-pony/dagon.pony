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
      TCPListener(recover Notifier(env, [buffy_name, sender_name, receiver_name]) end)
    else
      env.out.print("Parameters: buffy_binary giles_sender_binary giles_receiver_binary")
    end

class Notifier is TCPListenNotify
  let _env: Env
  var _buffy_name: String val = ""
  var _sender_name: String val = ""
  var _receiver_name: String val = ""

  var _host: String = ""
  var _service: String = ""

  new create(env: Env, process_names: Array[String val]) =>
    _env = env
    try
      _buffy_name = process_names(0)
      _sender_name = process_names(1)
      _receiver_name = process_names(2)
    else
      _env.out.print("dagon: couldn't get process names")
    end

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()

      // Start up processes
      // Send along ipaddress info so they can phone home

      _env.out.print("dagon: listening on " + _host + ":" + _service)
    else
      _env.out.print("dagon: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("dagon: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    Server(_env)

class Server is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("dagon: received")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon: server closed")
