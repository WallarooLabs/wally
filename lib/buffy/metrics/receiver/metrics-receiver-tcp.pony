use "net"
use "sendence/bytes"
use "sendence/messages"
use "../"

class MetricsNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _host: String
  let _service: String
  let _collections: Array[MetricsCollection tag] val
  let _coordinator: ReceiverCoordinator

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 host: String, service: String,
                 collections: Array[MetricsCollection tag] val,
                 coordinator: ReceiverCoordinator) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _host = host
    _service = service
    _collections = collections
    _coordinator = coordinator

  fun ref listening(listen: TCPListener ref) =>
    _coordinator.buffy_ready(listen)
    _stdout.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _coordinator.buffy_failed(listen)
    _stderr.print("couldn't listen")

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsReceiverNotify(_stdout, _stderr, _auth, _collections)

class MetricsReceiverNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _decoder: MetricsMsgDecoder = MetricsMsgDecoder
  var _header: Bool = true
  let _collections: Array[MetricsCollection tag] val

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 collections: Array[MetricsCollection tag] val) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _collections = collections

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _stdout.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    let d: Array[U8] val = consume data
    if _header then
      try
        let expect = Bytes.to_u32(d(0), d(1), d(2), d(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _stderr.print("Blew up reading header from Buffy")
      end
    else
      handle_data(consume d)
      conn.expect(4)
      _header = true
    end

  fun ref handle_data(data: (Array[U8] val | Array[U8] iso)) =>
      let msg = _decoder(consume data, _auth)
      match msg
      | let m: NodeMetricsSummary val =>
        process_data(m)
      | let m: BoundaryMetricsSummary val =>
        process_data(m)
      else
        _stderr.print("Message couldn't be decoded!")
      end

  fun ref process_data(m: (NodeMetricsSummary val | BoundaryMetricsSummary val))
  =>
    for mc in _collections.values() do
      mc.process_summary(m)
    end

  fun ref connected(conn: TCPConnection ref) =>
    _stdout.print("connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _stdout.print("connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _stdout.print("server closed")
