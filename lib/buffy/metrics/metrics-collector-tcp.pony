use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"
use "logger"

class MetricsCollectorNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _logger: Logger[String]

  new iso create(auth: AmbientAuth, logger': Logger[String]) =>
    _auth = auth
    _logger = logger'

  fun ref listening(listen: TCPListener ref) =>
    _logger(Info) and _logger.log("Metrics collector: listening.")

  fun ref not_listening(listen: TCPListener ref) =>
    _logger(Info) and _logger.log("Metrics collector: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsCollectorConnectNotify(_auth, _logger)

class MetricsCollectorConnectNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _logger: Logger[String]

  new iso create(auth: AmbientAuth, logger': Logger[String]) =>
    _auth = auth
    _logger = logger'

  fun ref accepted(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Metrics Collector: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
		_logger(Info) and _logger.log("Metrics Collector:  received data.")
    true

  fun ref connected(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Metrics Collector: connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _logger(Warn) and _logger.log("Metrics Collector: connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Metrics Collector: server closed")

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
    data
