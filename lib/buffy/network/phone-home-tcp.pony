use "net"
use "buffy/messages"
use "sendence/tcp"

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _coordinator: Coordinator
  let _framer: Framer = Framer

  new iso create(env: Env, auth: AmbientAuth, name: String,
    coordinator: Coordinator) =>
    _env = env
    _auth = auth
    _name = name
    _coordinator = coordinator

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print(_name + ": phone home connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let external_msg = ExternalMsgDecoder(chunked)
        match external_msg
        | let m: ExternalShutdownMsg val =>
          _coordinator.shutdown()
        end
      else
        _env.err.print("Phone home connection: error decoding phone home message")
      end
    end
    _env.out.print("Phone home channel: Received data")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")