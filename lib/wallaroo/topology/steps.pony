use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/messages"

actor Step
  let _runner: Runner
  var _conn: (TCPConnection | None) = None

  new create(runner: Runner iso) =>
    _runner = consume runner

  be update_connection(conn: TCPConnection) =>
    _conn = conn

  be run[In: Any val](metric_name: String, source_ts: U64,
    input: In, envelope: MsgEnvelope)
  =>
    _runner.run[In](metric_name, source_ts, input, _conn)

  be dispose() =>
    match _conn
    | let tcp: TCPConnection =>
      tcp.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

interface StepBuilder
  fun id(): U128

  fun apply(target: Step tag, metrics_conn: TCPConnection): Step tag
