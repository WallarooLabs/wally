use "debug"

use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"

class MetricsCollectorNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth

  new iso create(env: Env, auth: AmbientAuth) =>
    _env = env
    _auth = auth

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("Metrics collector: listening.")

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("Metrics collector: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsCollectorConnectNotify(_env, _auth)

class MetricsCollectorConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth

  new iso create(env: Env, auth: AmbientAuth) =>
    _env = env
    _auth = auth

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("Metrics Collector: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
		_env.out.print("Metrics Collector:  received data.")

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("Metrics Collector: connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("Metrics Collector: connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("Metrics Collector: server closed")

  fun ref sent(conn: TCPConnection ref, data: (String val | Array[U8 val] val))
  : (String val | Array[U8 val] val)  =>
    Debug(data)
    data
