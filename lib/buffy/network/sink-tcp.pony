use "net"
use "logger"

class SinkConnectNotify is TCPConnectionNotify
  let _env: Env
  let _logger: Logger[String]

  new iso create(env: Env, logger': Logger[String]) =>
    _env = env
    _logger = logger'

  fun ref accepted(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("sink: sink connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    true

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("sink: server closed")

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
    data
