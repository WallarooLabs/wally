use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"

class MetricsCollectorNotifier is TCPListenNotify
  let _stderr: StdStream
  let _stdout: StdStream
  let _auth: AmbientAuth

  new iso create(auth: AmbientAuth, stdout: StdStream, stderr: StdStream) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr

  fun ref listening(listen: TCPListener ref) =>
    _stdout.print("Metrics collector: listening.")

  fun ref not_listening(listen: TCPListener ref) =>
    _stdout.print("Metrics collector: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsCollectorConnectNotify(_auth, _stdout, _stderr)

class MetricsCollectorConnectNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _stderr: StdStream
  let _stdout: StdStream

  new iso create(auth: AmbientAuth, stdout: StdStream, stderr: StdStream) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr

  fun ref accepted(conn: TCPConnection ref) =>
    _stdout.print("Metrics Collector: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
		_stdout.print("Metrics Collector:  received data.")

  fun ref connected(conn: TCPConnection ref) =>
    _stdout.print("Metrics Collector: connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _stdout.print("Metrics Collector: connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _stdout.print("Metrics Collector: server closed")
