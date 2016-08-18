use "../metrics"
use "net"
use "buffered"  
use "time"  
use "debug" 
use "sendence/messages"
use "sendence/epoch"
 
trait SinkCollector[In: Any val, Diff: Any #read]
  fun ref apply(input: In)

  fun has_diff(): Bool

  fun ref diff(): Diff

  fun ref clear_diff()

actor EmptySink is ComputeStep[None]
  let _metrics_collector: (MetricsCollector tag | None)
  let _pipeline_name: String
  var _sink_reporter: (MetricsReporter | None) = None
  var _node_reporter: (MetricsReporter | None) = None

  new create(m_coll: (MetricsCollector tag | None), pipeline_name: String) 
  =>
    _metrics_collector = m_coll
    _pipeline_name = pipeline_name
    _sink_reporter = MetricsReporter(0, _pipeline_name, "source-sink", 
      _metrics_collector)
    _node_reporter = MetricsReporter(0, "leader", "ingress-egress", 
      _metrics_collector)

  be add_conn(conn: TCPConnection) => None

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
      match _sink_reporter
      | let sr: MetricsReporter =>
        sr.report((Epoch.nanoseconds() - source_ts))
      end
      match _node_reporter
      | let sr: MetricsReporter =>
        sr.report((Epoch.nanoseconds() - ingress_ts))
      end

actor ExternalConnection[In: Any val] is ComputeStep[In]
  let _array_stringify: ArrayStringify[In] val
  let _conns: Array[TCPConnection]
  let _metrics_collector: (MetricsCollector tag | None)
  let _pipeline_name: String
  var _sink_reporter: (MetricsReporter | None) = None
  var _node_reporter: (MetricsReporter | None) = None
  embed _write_buffer: Writer = Writer

  new create(array_stringify: ArrayStringify[In] val, 
    conns: Array[TCPConnection] iso =
    recover Array[TCPConnection] end, m_coll: (MetricsCollector tag | None),
    pipeline_name: String, 
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end) 
  =>
    _array_stringify = array_stringify
    _conns = consume conns
    _metrics_collector = m_coll
    _pipeline_name = pipeline_name
    _sink_reporter = MetricsReporter(0, _pipeline_name, "source-sink", 
      _metrics_collector)
    _node_reporter = MetricsReporter(0, "leader", "ingress-egress", 
      _metrics_collector)
    for conn in _conns.values() do
      for msg in initial_msgs.values() do
        conn.writev(msg)
      end
    end

  be add_conn(conn: TCPConnection) =>
    _conns.push(conn)

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      try
        let out = _array_stringify(input)
        ifdef debug then
          Debug.out(
            match out
            | let s: String =>
              ">>>>" + s + "<<<<"
            | let arr: Array[String] val =>
              ">>>>" + ",".join(arr) + "<<<<"
            end
          )
        end
        let tcp_msg = FallorMsgEncoder(out, _write_buffer)
        for conn in _conns.values() do
          conn.writev(tcp_msg)
        end
        match _sink_reporter
        | let sr: MetricsReporter =>
          sr.report((Epoch.nanoseconds() - source_ts))
        end
        match _node_reporter
        | let sr: MetricsReporter =>
          sr.report((Epoch.nanoseconds() - ingress_ts))
        end
      end
    end

actor CollectorSinkStep[In: Any val, Diff: Any #read] is ComputeStep[In]
  let _collector: SinkCollector[In, Diff]
  let _array_byteseqify: ArrayByteSeqify[Diff] val
  let _conns: Array[TCPConnection]
  let _metrics_collector: (MetricsCollector tag | None)
  let _pipeline_name: String
  var _sink_reporter: (MetricsReporter | None) = None
  var _node_reporter: (MetricsReporter | None) = None
  let _timers: Timers = Timers
  embed _wb: Writer = Writer

  new create(collector_builder: {(): SinkCollector[In, Diff]} val, 
    array_byteseqify: ArrayByteSeqify[Diff] val,
    conns: Array[TCPConnection] iso = recover Array[TCPConnection] end, 
    m_coll: (MetricsCollector tag | None), pipeline_name: String,
    initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end) 
  =>
    _collector = collector_builder()
    _array_byteseqify = array_byteseqify
    _conns = consume conns
    _metrics_collector = m_coll
    _pipeline_name = pipeline_name
    let t = Timer(_SendDiff[In, Diff](this), 1_000_000_000, 1_000_000_000)
    _timers(consume t)
    _sink_reporter = MetricsReporter(0, _pipeline_name, "source-sink", 
      _metrics_collector)
    _node_reporter = MetricsReporter(0, "leader", "ingress-egress", 
      _metrics_collector)
    for conn in _conns.values() do
      for msg in initial_msgs.values() do
        conn.writev(msg)
      end
    end

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>  
      _collector(input)
    end
    let now = Epoch.nanoseconds()
    match _sink_reporter
    | let sr: MetricsReporter =>
      sr.report((Epoch.nanoseconds() - source_ts))
    end
    match _node_reporter
    | let sr: MetricsReporter =>
      sr.report((Epoch.nanoseconds() - ingress_ts))
    end

  be send_diff() =>
    if _collector.has_diff() then
      try
        let byteseqified = _array_byteseqify(_collector.diff(), _wb)
        for conn in _conns.values() do
          conn.writev(byteseqified)
          // match stringified
          // | let s: String val => 
          //   conn.write(s)
          // | let a: Array[String val] val => 
          //   conn.writev(a)
          // end
        end
        _collector.clear_diff()
      end
    end

class _SendDiff[In: Any val, Diff: Any #read] is TimerNotify
  let _step: CollectorSinkStep[In, Diff] tag

  new iso create(step: CollectorSinkStep[In, Diff] tag) =>
    _step = step

  fun ref apply(timer: Timer, count: U64): Bool =>
    _step.send_diff()
    true 
