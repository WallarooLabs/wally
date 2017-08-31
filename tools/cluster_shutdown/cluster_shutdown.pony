use "net"
use "sendence/messages"

actor Main
  new create(env: Env) =>
    var _conn: (TCPConnection | None) = None

    try
      (let service, let port) = env.args(0).split(":")

      let auth = env.root as AmbientAuth
      let tcp_auth = TCPConnectAuth(auth)
      TCPConnection(tcp_auth, Notifier(env), service, host)
    else
      env.err.out("Must supply valid cluster address")
      env.exitcode(1)
    end

class Notifier is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(ExternalMessageEncoder.clean_shutdown())
    conn.dispose()

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.out("Error: Unable to connect")
    env.exitcode(1)

