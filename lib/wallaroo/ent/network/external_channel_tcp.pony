use "net"
use "collections"
use "time"
use "sendence/bytes"
use "sendence/messages"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/topology"

class ExternalChannelListenNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _worker_name: String
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections

  new iso create(name: String, auth: AmbientAuth, connections: Connections)
  =>
    _auth = auth
    _worker_name = name
    _connections = connections

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      if _host == "::1" then _host = "127.0.0.1" end

      @printf[I32]("%s external: listening on %s:%s\n".cstring(),
        _worker_name.cstring(), _host.cstring(), _service.cstring())
    else
      @printf[I32]("%s external: couldn't get local address\n".cstring(),
        _worker_name.cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]("%s external: couldn't listen\n".cstring(),
      _worker_name.cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ExternalChannelConnectNotifier(_worker_name, _auth, _connections)

class ExternalChannelConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _connections: Connections
  var _header: Bool = true

  new iso create(name: String, auth: AmbientAuth, connections: Connections)
  =>
    _auth = auth
    _worker_name = name
    _connections = connections

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on external channel\n".cstring())
      end
    else
      ifdef "trace" then
        @printf[I32]("Received msg on External Channel\n".cstring())
      end
      try
        let msg = ExternalMsgDecoder(consume data)
        match msg
        | let m: ExternalPrintMsg =>
          ifdef "trace" then
            @printf[I32]("Received ExternalPrintMsg on External Channel\n"
              .cstring())
          end
          @printf[I32]("$$$ ExternalPrint: %s $$$\n".cstring(),
            m.message.cstring())
        | let m: ExternalRotateLogFilesMsg =>
          ifdef "trace" then
            @printf[I32](("Received ExternalRotateLogFilesMsg on External " +
              "Channel\n").cstring())
          end
          _connections.rotate_log_files(m.node_name)
        else
          @printf[I32](("Incoming External Message type not handled by " +
            "external channel.\n").cstring())
        end
      else
        @printf[I32]("Error decoding External Message on external channel.\n"
          .cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    @printf[I32]("%s external channel is connected.\n".cstring(),
      _worker_name.cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("%s external: connection failed!\n".cstring(),
      _worker_name.cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("ExternalChannelConnectNotifier: %s: server closed\n"
      .cstring(), _worker_name.cstring())
