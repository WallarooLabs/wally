use "net"
use "sendence/messages"
use "sendence/tcp"
use "options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    let args = options.remaining()

    try
      let auth = env.root as AmbientAuth

      let addr = args(1).split(":")
      let host = addr(0)
      let service = addr(1)
      TCPListener(auth, ListenNotifier(env, host, service), host, service)
    else
      env.out.print("Something went wrong!")
    end

class ListenNotifier is TCPListenNotify
  let _env: Env
  let _host: String
  let _service: String

  new iso create(env: Env, host: String, service: String) =>
    _env = env
    _host = host
    _service = service

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ConnectNotify(_env)

class ConnectNotify is TCPConnectionNotify
  let _env: Env
  let _framer: Framer = Framer

  new iso create(env: Env) =>
    _env = env

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(chunked)
        match decoded
        | let d: ExternalDataMsg val =>
          _env.out.print("<<<" + d.data + ">>>")
        else
          _env.err.print("Error decoding message")
        end
      else
        _env.err.print("Error decoding message")
      end
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("Server closed")
