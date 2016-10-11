use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/resilience"
use "wallaroo/messages"

actor Step is EventLogReplayTarget
  let _runner: Runner
  var _conn: (TCPConnection | None) = None
  // let _h-wm: HighWaterMarkTable = HighWaterMarkTable()
  // let _l-wm: LowWaterMarkTable = LowWaterMarkTable()
  // let _translate: TranslationTable = TranslationTable()
  
  new create(runner: Runner iso) =>
    _runner = consume runner
    _runner.set_buffer_target(this)

  be update_connection(conn: TCPConnection) =>
    _conn = conn

  be run[In: Any val](metric_name: String, source_ts: U64,
    input: In, envelope: MsgEnvelope val)
  =>
    // this only works with John's new API  
    // let done: Bool = _runner.run[In](metric_name, source_ts, input, _conn)

  be replay_log_entry(log_entry: LogEntry val) =>
    _runner.replay_log_entry(log_entry)

  be replay_finished() =>
    //TODO: clear deduplication logs
    None
    _runner.run[In](metric_name, source_ts, input, _conn)
    let done = true
    // Process envelope if we're done
    // Note: We do the bookkeeping _after_ handing the computation result
    //       to the next Step.
    if done then
      _bookkeeping(envelope)
    end
    
  be dispose() =>
    match _conn
    | let tcp: TCPConnection =>
      tcp.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

  fun ref _bookkeeping(envelope: MsgEnvelope val)
  =>
    """
    Process envelope and keep track of things
    """
    

    
interface StepBuilder
  fun id(): U128

  fun apply(target: Step tag, metrics_conn: TCPConnection): Step tag
