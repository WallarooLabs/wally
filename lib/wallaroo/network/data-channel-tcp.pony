use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/metrics"
use "wallaroo/topology"

class DataChannelNotify is TCPConnectionNotify
  let _router: Router val
  let _metrics: JrMetrics
  var _header: Bool = true

  new iso create(router: Router val, metrics: JrMetrics) =>
    _router = router
    _metrics = metrics

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      // process consume data

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class DataChannelListenerNotify is TCPListenNotify
  let _router: Router val
  let _metrics: JrMetrics

  new iso create(router: Router val, metrics: JrMetrics) =>
    _router = router
    _metrics = metrics

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    DataChannelNotify(_router, _metrics)