use "net"
use "../topology"
use "sendence/bytes"
use "buffy/messages"

trait SinkNodeStepBuilder
  fun apply(conn: TCPConnection): StringInStep tag

class SinkNodeConfig[Diff: Any #read] is SinkNodeStepBuilder
  let collector_builder: {(): SinkCollector[Diff]} val
  let connector: SinkConnector val
  let stringify: Stringify[Diff] val
  
  new val create(collector_builder': {(): SinkCollector[Diff]} val,
    connector': SinkConnector val, stringify': Stringify[Diff] val) 
  =>
    collector_builder = collector_builder'
    connector = connector'
    stringify = stringify'

  fun apply(conn: TCPConnection): StringInStep tag =>
    let sink_connection = SinkConnection(conn, connector)

    SinkNodeStep[Diff](collector_builder, stringify, sink_connection)

trait SinkCollector[Diff: Any #read]
  fun ref apply(input: String)

  fun has_diff(): Bool

  fun ref diff(): Diff

  fun ref clear_diff()

trait SinkConnector
  fun apply(conn: TCPConnection)

actor SinkConnection
  var _conn: TCPConnection

  new create(conn: TCPConnection, sink_connector: SinkConnector val) =>
    _conn = conn
    sink_connector(_conn)

  be update_conn(conn: TCPConnection) =>
    _conn = conn

  be apply(s: String) =>
    _conn.writev(Bytes.length_encode(s))
