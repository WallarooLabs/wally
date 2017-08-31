use "net"

class iso JoiningListenNotifier is TCPListenNotify
  """
  The sole purpose of this listener is to keep a joining worker process alive
  while waiting to get cluster info and initialize.
  TODO: Eliminate the need for this.
  """
  fun ref listening(listen: TCPListener ref) =>
    try
      (let host, let service) = listen.local_address().name()
      @printf[I32](("Joining Worker Listener listening on " + host + ":" +
        service + "\n").cstring())
    else
      @printf[I32]("Joining Worker Listener: couldn't get local address\n"
        .cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]("Joining Worker Listener: couldn't listen\n".cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    JoiningConnectNotifier

class JoiningConnectNotifier is TCPConnectionNotify
  fun ref connected(conn: TCPConnection ref) =>
    None

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true
