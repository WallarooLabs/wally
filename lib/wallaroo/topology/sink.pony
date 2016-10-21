use "buffered"
use "net"
use "collections"
use "wallaroo/messages"
use "wallaroo/metrics"

class SimpleSinkRunner is Runner
  let _metrics_reporter: MetricsReporter
  let _deduplication_list: Array[MsgEnvelope box]

  new iso create(metrics_reporter: MetricsReporter iso) =>
    _metrics_reporter = consume metrics_reporter
    _deduplication_list = Array[MsgEnvelope box]

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope box,
    router: (Router val | None) = None): Bool
  =>
    //TODO: create outgoing envelope?
    match data
    | let s: Stringable val => None
      @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
    else
      @printf[I32]("Simple sink: Got it!\n".cstring())
    end
    true

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope box,
    router: (Router val | None) = None): Bool
  =>
    if not is_duplicate_message(incoming_envelope) then
      _deduplication_list.push(incoming_envelope)
      run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
        router)
    else
      //we can pretend it stopped here because everything downstream know about
      //this
      true
    end

  fun is_duplicate_message(env: MsgEnvelope box): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e.msg_uid != env.msg_uid then
        continue
      else
        match (e.frac_ids, env.frac_ids)
        | (let efa: Array[U64] val, let efb: Array[U64] val) => 
          if efa.size() == efb.size() then
            var found = false
            for i in Range(0,efa.size()) do
              try
                if efa(i) != efb(i) then
                  found = false
                  break
                end
              else
                found = false
                break
              end
            end
            if found then
              return true
            end
          end
        | (None,None) => return true
        else
          continue
        end
      end
    end
    false

class EncoderSinkRunner[In: Any val] is Runner
  let _metrics_reporter: MetricsReporter
  let _target: Router val
  let _encoder: SinkEncoder[In] val
  let _wb: Writer = Writer
  let _deduplication_list: Array[MsgEnvelope box]

  new iso create(encoder: SinkEncoder[In] val,
    target: Router val,
    metrics_reporter: MetricsReporter iso,
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end)
  =>
    _metrics_reporter = consume metrics_reporter
    _target = target
    _encoder = encoder
    //TODO: do we need to make sure we only send these when we're not recovering?
    match _target
    | let tcp: TCPRouter val =>
      for msg in initial_msgs.values() do
        tcp.writev(msg)
      end
    end
    _deduplication_list = Array[MsgEnvelope box]

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope box,
    router: (Router val | None) = None): Bool
  =>
    match data
    | let input: In =>
      let encoded = _encoder(input, _wb)
      _target.route[Array[ByteSeq] val](metric_name, source_ts, encoded,
        origin, msg_uid, frac_ids, seq_id, incoming_envelope)
    else
      @printf[I32]("Encoder sink received unrecognized input type.")
    end
    true

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope box,
    router: (Router val | None) = None): Bool
  =>
    if not is_duplicate_message(incoming_envelope) then
      _deduplication_list.push(incoming_envelope)
      run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
        router)
    else
      //we can pretend it stopped here because everything downstream know about
      //this
      true
    end

  fun is_duplicate_message(env: MsgEnvelope box): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e.msg_uid != env.msg_uid then
        continue
      else
        match (e.frac_ids, env.frac_ids)
        | (let efa: Array[U64] val, let efb: Array[U64] val) => 
          if efa.size() == efb.size() then
            var found = false
            for i in Range(0,efa.size()) do
              try
                if efa(i) != efb(i) then
                  found = false
                  break
                end
              else
                found = false
                break
              end
            end
            if found then
              return true
            end
          end
        | (None,None) => return true
        else
          continue
        end
      end
    end
    false

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
