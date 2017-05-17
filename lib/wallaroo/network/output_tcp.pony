use "net"
use "wallaroo/fail"

class OutNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String) =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing connected\n".cstring(),
      _name.cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    Fail()

  fun ref throttled(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing throttled\n".cstring(),
      _name.cstring())

  fun ref unthrottled(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing no longer throttled\n".cstring(),
      _name.cstring())
