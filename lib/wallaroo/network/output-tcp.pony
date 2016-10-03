use "net"

class OutNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String) =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing connected\n".cstring(),
      _name.null_terminated().cstring())

  fun ref throttled(sock: TCPConnection ref, x: Bool) =>
    if x then
      @printf[None]("%s outgoing throttled\n".cstring(),
        _name.null_terminated().cstring())
    else
      @printf[None]("%s outgoing no longer throttled\n".cstring(),
        _name.null_terminated().cstring())
    end