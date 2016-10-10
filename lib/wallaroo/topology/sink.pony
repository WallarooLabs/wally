use "buffered"
use "net"
use "wallaroo/messages"
use "wallaroo/metrics"

class SimpleSinkRunner
  let _metrics_reporter: MetricsReporter

  new iso create(metrics_reporter: MetricsReporter iso) =>
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](metric_name: String, source_ts: U64, data: D,
    router: (Router val | None)): Bool
  =>
    match data
    | let s: Stringable val => None
      // @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
    else
      @printf[I32]("Simple sink: Got it!\n".cstring())
    end

    _metrics_reporter.pipeline_metric(metric_name, source_ts)
    true

class EncoderSinkRunner[In: Any val]
  let _metrics_reporter: MetricsReporter
  let _next: Runner = RouterRunner
  let _encoder: SinkEncoder[In] val
  let _wb: Writer = Writer

  new iso create(encoder: SinkEncoder[In] val,
    metrics_reporter: MetricsReporter iso,
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end)
  =>
    _metrics_reporter = consume metrics_reporter
    _encoder = encoder
    for msg in initial_msgs.values() do
      _target.writev(msg)
    end

  fun ref run[D: Any val](metric_name: String, source_ts: U64, data: D,
    router: (Router val | None)): Bool
  =>
    match data
    | let input: In =>
      let encoded = _encoder(input, _wb)
      _next.run[Array[ByteSeq] val](metric_name, source_ts, encoded, router)
    else
      @printf[I32]("Encoder sink received unrecognized input type.")
    end
    _metrics_reporter.pipeline_metric(metric_name, source_ts)
    true

trait SinkBuilder
  fun apply(metrics_reporter: MetricsReporter iso, next: (Router val | None) = 
    None): Runner iso^

  fun name(): String
  // fun is_stateful(): Bool

class SimpleSinkRunnerBuilder[In: Any val] is SinkBuilder
  let _pipeline_name: String

  new val create(pipeline_name: String) =>
    _pipeline_name = pipeline_name

  fun apply(metrics_reporter: MetricsReporter iso, next: (Router val | None)): 
    Runner iso^ 
  =>
    SimpleSinkRunner(consume metrics_reporter) 

  fun name(): String => _pipeline_name + " sink"
  fun is_stateful(): Bool => false

class EncoderSinkRunnerBuilder[In: Any val] is SinkBuilder
  let _encoder: SinkEncoder[In] val
  let _pipeline_name: String
  let _initial_msgs: Array[Array[ByteSeq] val] val 

  new val create(encoder: SinkEncoder[In] val, 
    pipeline_name: String, initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end) 
  =>
    _encoder = encoder
    _pipeline_name = pipeline_name
    _initial_msgs = initial_msgs

  fun apply(metrics_reporter: MetricsReporter iso, next: (Router val | None)): 
    Runner iso^ 
  =>
    EncoderSinkRunner[In](_encoder, consume metrics_reporter, _initial_msgs) 

  fun name(): String => _pipeline_name + " sink"
  fun is_stateful(): Bool => false


// class SimpleSink
//   let _metrics_reporter: MetricsReporter

//   new iso create(metrics_reporter: MetricsReporter iso) =>
//     _metrics_reporter = consume metrics_reporter

//   fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
//     conn: (TCPConnection | None))
//   =>
//     match input
//     | let s: Stringable val => None
//       // @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
//     else
//       @printf[I32]("Simple sink: Got it!\n".cstring())
//     end

//     _metrics_reporter.pipeline_metric(metric_name, source_ts)

// class EncoderSink//[Out: Any val]
//   let _metrics_reporter: MetricsReporter
//   let _conn: TCPConnection
//   // let _encoder: {(Out): Array[ByteSeq] val} val

//   new iso create(metrics_reporter: MetricsReporter iso,
//     conn: TCPConnection)
//   // , encoder: {(Out): Array[ByteSeq] val} val)
//   =>
//     _metrics_reporter = consume metrics_reporter
//     _conn = conn
//     // _encoder = encoder

//   fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
//     conn: (TCPConnection | None))
//   =>
//     _conn.write("hi")
//     // match input
//     // | let o: Out =>
//       // let encoded = _encoder(o)
//     // end

//     _metrics_reporter.pipeline_metric(metric_name, source_ts)