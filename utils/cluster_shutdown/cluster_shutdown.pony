use "net"
use "sendence/messages"

actor Main
  new create(env: Env) =>
    try
      let split = env.args(0).split(":")
      let service = split(0)
      let port = split(1)

      let auth = env.root as AmbientAuth
      let tcp_auth = TCPConnectAuth(auth)
      TCPConnection(tcp_auth, Notifier(env), service, port)
    else
      env.err.print("Must supply valid cluster address")
      env.exitcode(1)
    end

class Notifier is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(ExternalMsgEncoder.clean_shutdown())
    conn.dispose()

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Error: Unable to connect")
    _env.exitcode(1)

