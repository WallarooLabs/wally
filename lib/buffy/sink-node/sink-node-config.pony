use "net"
use "../topology"
use "sendence/bytes"
use "buffy/messages"

trait SinkNodeStepBuilder
  fun apply(conn: TCPConnection): StringInStep tag

class SinkNodeConfig[Diff: Any #read] is SinkNodeStepBuilder
  let collector_builder: {(): SinkCollector[Diff]} val
  let connector: SinkConnector val
  let stringify: ArrayStringify[Diff] val
  
  new val create(collector_builder': {(): SinkCollector[Diff]} val,
    connector': SinkConnector val, stringify': ArrayStringify[Diff] val) 
  =>
    collector_builder = collector_builder'
    connector = connector'
    stringify = stringify'

  fun apply(conn: TCPConnection): StringInStep tag =>
    let sink_connection = SinkConnection(conn, connector)

    SinkNodeStep[Diff](collector_builder, stringify, sink_connection)

trait SinkCollector[Diff: Any #read]
  fun ref apply(input: Array[String] val)

  fun has_diff(): Bool

  fun ref diff(): Diff

  fun ref clear_diff()

trait SinkConnector
  fun apply(conn: TCPConnection)

actor SinkConnection
  let _wb: WriteBuffer = WriteBuffer
  var _conn: TCPConnection

  new create(conn: TCPConnection, sink_connector: SinkConnector val) =>
    _conn = conn
    sink_connector(_conn)

  be update_conn(conn: TCPConnection) =>
    _conn = conn

  be apply(strings: (String | Array[String] val)) =>
    match strings
    | let s: String =>
      _wb.u32_be(s.size().u32())
      _wb.write(s)
      _conn.writev(_wb.done())
    | let arr: Array[String] val =>
      for s in arr.values() do
        _wb.u32_be(s.size().u32())
        _wb.write(s)
      end
      _conn.writev(_wb.done())
    end
