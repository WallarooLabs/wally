use "buffered"
use "net"
use "wallaroo/messages"
use "wallaroo/metrics"

class SimpleSinkRunner is Runner
  let _metrics_reporter: MetricsReporter

  new iso create(metrics_reporter: MetricsReporter iso) =>
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    outgoing_envelope: MsgEnvelope ref, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    //TODO: stamp outgoing envelope?
    match data
    | let s: Stringable val => None
      @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
    else
      @printf[I32]("Simple sink: Got it!\n".cstring())
    end

    true

class EncoderSinkRunner[In: Any val] is Runner
  let _metrics_reporter: MetricsReporter
  let _target: Router val
  let _encoder: SinkEncoder[In] val
  let _wb: Writer = Writer

  new iso create(encoder: SinkEncoder[In] val,
    target: Router val,
    metrics_reporter: MetricsReporter iso,
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end)
  =>
    _metrics_reporter = consume metrics_reporter
    _target = target
    _encoder = encoder
    match _target
    | let tcp: TCPRouter val =>
      for msg in initial_msgs.values() do
        tcp.writev(msg)
      end
    end

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    outgoing_envelope: MsgEnvelope ref, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    match data
    | let input: In =>
      let encoded = _encoder(input, _wb)
      _target.route[Array[ByteSeq] val](metric_name, source_ts, encoded,
        outgoing_envelope, incoming_envelope)
    else
      @printf[I32]("Encoder sink received unrecognized input type.")
    end

    true

trait SinkRunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, next: Router val = 
    EmptyRouter): Runner iso^

  fun name(): String 

class SimpleSinkRunnerBuilder[In: Any val] is SinkRunnerBuilder
  let _pipeline_name: String

  new val create(pipeline_name: String) =>
    _pipeline_name = pipeline_name

  fun apply(metrics_reporter: MetricsReporter iso, next: Router val =
      EmptyRouter): Runner iso^ 
  =>
    SimpleSinkRunner(consume metrics_reporter) 

  fun name(): String => _pipeline_name + " sink"

class EncoderSinkRunnerBuilder[In: Any val] is SinkRunnerBuilder
  let _encoder: SinkEncoder[In] val
  let _pipeline_name: String
  let _initial_msgs: Array[Array[ByteSeq] val] val 

  new val create(pipeline_name: String, encoder: SinkEncoder[In] val, 
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end) 
  =>
    _encoder = encoder
    _pipeline_name = pipeline_name
    _initial_msgs = initial_msgs

  fun apply(metrics_reporter: MetricsReporter iso, next: Router val): 
    Runner iso^ 
  =>
    EncoderSinkRunner[In](_encoder, next, consume metrics_reporter, 
      _initial_msgs) 

  fun name(): String => _pipeline_name + " sink"
