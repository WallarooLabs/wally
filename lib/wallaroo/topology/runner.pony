use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/messages"
use "wallaroo/resilience"

interface Runner
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    conn: (TCPConnection | None))

class ComputationRunner[In: Any val, Out: Any val]
  let _computation: Computation[In, Out] val
  let _computation_name: String
  let _target: Step tag
  let _metrics_reporter: MetricsReporter

  new iso create(computation: Computation[In, Out] val, 
    target: Step tag,
    metrics_reporter: MetricsReporter iso) 
  =>
    _computation = computation
    _computation_name = _computation.name()
    _target = target
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](source_name: String val, source_ts: U64, input: D,
    conn: (TCPConnection | None))
  =>
    let computation_start = Time.nanos()
    match input
    | let i: In =>
      match _computation(i)
      | let output: Out =>
        _target.run[Out](source_name, source_ts, output)
      else
        _metrics_reporter.pipeline_metric(source_name, source_ts)
      end

      let computation_end = Time.nanos()   

      _metrics_reporter.step_metric(_computation_name,
        computation_start, computation_end)
    end

class StateRunner[State: Any #read]
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _wb: Writer = Writer
  let _state_change_repository: StateChangeRepository[State] ref
  let _event_log_buffer: EventLogBuffer tag
  let _alfred: Alfred

  new iso create(state_builder: {(): State} val, 
    metrics_reporter: MetricsReporter iso,
    alfred: Alfred, event_log_buffer: EventLogBuffer tag
    ) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter
    _state_change_repository = StateChangeRepository[State]
    _alfred = alfred
    _event_log_buffer = consume event_log_buffer

  fun ref register_state_change(sc: StateChange[State] ref) : U64 =>
    _state_change_repository.register(sc)

  fun ref run[In: Any val](source_name: String val, source_ts: U64, input: In,
    conn: (TCPConnection | None))
  =>
    match input
    | let sp: StateProcessor[State] val =>
      let computation_start = Time.nanos()
      match sp(_state, _state_change_repository, _wb)
      | let sc: StateChange[State] =>
        //TODO: these two should come from the deduplication stuff
        let uid: U64 = 0
        let fractional_list: Array[U64] val = recover val Array[U64] end
        let log_entry = LogEntry(uid, fractional_list, sc.id(), sc.to_log_entry()) 
        _event_log_buffer.queue(log_entry)
      end
      let computation_end = Time.nanos()

      _metrics_reporter.pipeline_metric(source_name, source_ts)

      _metrics_reporter.step_metric(sp.name(),
        computation_start, computation_end)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
    end

class Proxy
  let _worker_name: String
  let _target_step_id: U128
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth

  new iso create(worker_name: String, target_step_id: U128, 
    metrics_reporter: MetricsReporter iso, auth: AmbientAuth) 
  =>
    _worker_name = worker_name
    _target_step_id = target_step_id
    _metrics_reporter = consume metrics_reporter
    _auth = auth

  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    conn: (TCPConnection | None))
  =>
    match conn
    | let tcp: TCPConnection =>
      try
        let forward_msg = ChannelMsgEncoder.data_channel[In](_target_step_id, 
          0, _worker_name, source_ts, input, metric_name, _auth)
        tcp.writev(forward_msg)
      else
        @printf[I32]("Problem encoding forwarded message\n".cstring())
      end
    end

    // _metrics_reporter.worker_metric(metric_name, source_ts)  

class SimpleSink
  let _metrics_reporter: MetricsReporter

  new iso create(metrics_reporter: MetricsReporter iso) =>
    _metrics_reporter = consume metrics_reporter

  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    conn: (TCPConnection | None))
  =>
    match input
    | let s: Stringable val => None
      // @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
    else
      @printf[I32]("Simple sink: Got it!\n".cstring())
    end

    _metrics_reporter.pipeline_metric(metric_name, source_ts)

class EncoderSink//[Out: Any val]
  let _metrics_reporter: MetricsReporter
  let _conn: TCPConnection
  // let _encoder: {(Out): Array[ByteSeq] val} val

  new iso create(metrics_reporter: MetricsReporter iso,
    conn: TCPConnection)
  // , encoder: {(Out): Array[ByteSeq] val} val)
  =>
    _metrics_reporter = consume metrics_reporter
    _conn = conn
    // _encoder = encoder

  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    conn: (TCPConnection | None))
  =>
    _conn.write("hi")
    // match input
    // | let o: Out =>
      // let encoded = _encoder(o)
    // end

    _metrics_reporter.pipeline_metric(metric_name, source_ts)
