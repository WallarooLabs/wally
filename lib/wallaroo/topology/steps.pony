use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/resilience"

actor Step is EventLogReplayTarget
  let _runner: Runner
  var _conn: (TCPConnection | None) = None

  new create(runner: Runner iso) =>
    _runner = consume runner
    _runner.set_buffer_target(this)

  be update_connection(conn: TCPConnection) =>
    _conn = conn

  be run[In: Any val](metric_name: String, source_ts: U64, input: In) =>
    _runner.run[In](metric_name, source_ts, input, _conn)

  be replay_log_entry(log_entry: LogEntry val) =>
    _runner.replay_log_entry(log_entry)

  be replay_finished() =>
    //TODO: clear deduplication logs
    None

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
