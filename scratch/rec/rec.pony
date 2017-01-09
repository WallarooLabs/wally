use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "sendence/tcp"
use "options"

actor Main
  new create(env: Env) =>
    var options = Options(env.args)
    var args = options.remaining()
    try
      let auth = env.root as AmbientAuth
      let addr: Array[String] = args(1).split(":")
      let host = addr(0)
      let service = addr(1)
      TCPListener(auth, Notifier(env), host, service)
    end

class Notifier is TCPListenNotify
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

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = ReportMsgDecoder(consume chunked)
        match msg
        | let m: NodeMetricsSummary val =>
          _env.out.print("Node metrics message.")
        | let m: BoundaryMetricsSummary val =>
          _env.out.print("Boundary metrics message.")
        else
          _env.err.print("Message couldn't be decoded!")
        end
      else
        _env.err.print("Error decoding incoming message.")
      end
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("server closed")
