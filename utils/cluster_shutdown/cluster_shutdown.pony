use "net"
use "sendence/messages"

actor Main
  new create(env: Env) =>
    try
      let split = env.args(0).split(":")
      let host = split(0)
      let service = split(1)

      let auth = env.root as AmbientAuth
      let tcp_auth = TCPConnectAuth(auth)
      TCPConnection(tcp_auth, Notifier(env, host, service), host, service)
    else
      env.err.print("usage: cluster_shutdown HOST:PORT")
      env.exitcode(1)
    end

class Notifier is TCPConnectionNotify
  let _env: Env
  let _host: String
  let _service: String

  new iso create(env: Env, host: String, service: String) =>
    _env = env
    _host = host
    _service = service

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(ExternalMsgEncoder.clean_shutdown())
    conn.dispose()

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Error: Unable to connect to " + _service + ":" + _host)
    _env.exitcode(1)

