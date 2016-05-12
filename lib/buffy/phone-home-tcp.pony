use "net"
use "buffy/messages"
use "sendence/tcp"

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String
  let _coordinator: Coordinator
  let _framer: Framer = Framer

  new iso create(env: Env, name: String, coordinator: Coordinator) =>
    _env = env
    _name = name
    _coordinator = coordinator

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print(_name + ": phone home connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = WireMsgDecoder(consume chunked)
        match msg
        | let d: ShutdownMsg val =>
          _coordinator.shutdown()
        | let m: UnknownMsg val =>
          _env.err.print("Unknown message type.")
        end
      else
        _env.err.print("Error decoding incoming message.")
      end
    end
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")