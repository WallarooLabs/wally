use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/metrics"
use "wallaroo/topology"

class SourceNotify is TCPConnectionNotify
  let _source: SourceRunner
  var _header: Bool = true

  new iso create(source: SourceRunner iso) =>
    _source = consume source

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      _source.process(consume data)

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class SourceListenerNotify is TCPListenNotify
  let _source_builder: {(): Source iso^} val
  let _metrics: JrMetrics
  let _expected: USize

  new iso create(source_builder: {(): Source iso^} val, metrics: JrMetrics, 
    expected: USize) =>
    _source_builder = source_builder
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    SourceNotify(SourceRunner(_source_builder(), _metrics, _expected))