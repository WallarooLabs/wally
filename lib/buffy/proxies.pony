use "collections"
use "debug"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "time"

actor Proxy is BasicStep
  let _env: Env
  let _step_id: I32
  let _conn: TCPConnection
  let _metrics_collector: MetricsCollector tag

  new create(env: Env, step_id: I32, conn: TCPConnection,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _step_id = step_id
    _conn = conn
    _metrics_collector = metrics_collector

  // input will be a Message[In] once the typearg issue is fixed
  // ponyc #723
  be apply(input: StepMessage val) =>
    match input
    | let m: Message[I32] val =>
      let tcp_msg = WireMsgEncoder.forward_i32(_step_id, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _conn.write(tcp_msg)
    | let m: Message[F32] val =>
      let tcp_msg = WireMsgEncoder.forward_f32(_step_id, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _conn.write(tcp_msg)
    | let m: Message[String] val =>
      let tcp_msg = WireMsgEncoder.forward_string(_step_id, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _conn.write(tcp_msg)
    end

actor ExternalConnection[In: OSCEncodable val] is ComputeStep[In]
  let _stringify: {(In): String ?} val
  let _conn: TCPConnection
  let _metrics_collector: MetricsCollector tag

  new create(stringify: {(In): String ?} val, conn: TCPConnection,
    m_coll: MetricsCollector tag) =>
    _stringify = stringify
    _conn = conn
    _metrics_collector = m_coll

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      try
        let str = _stringify(m.data)
        @printf[String]((str + "\n").cstring())
        let tcp_msg = WireMsgEncoder.external(str)
        _conn.write(tcp_msg)
        _metrics_collector.report_boundary_metrics(BoundaryTypes.source_sink(),
          m.id, m.source_ts, Time.millis())
      end
    end

actor StepManager
  let _env: Env
  let _metrics_collector: MetricsCollector tag
  let _steps: Map[I32, BasicStep tag] = Map[I32, BasicStep tag]
  let _sink_addrs: Map[I32, (String, String)] val
  let _step_lookup: StepLookup val

  new create(env: Env, step_lookup: StepLookup val,
    sink_addrs: Map[I32, (String, String)] val,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _sink_addrs = sink_addrs
    _step_lookup = step_lookup
    _metrics_collector = metrics_collector

  be apply(step_id: I32, msg: StepMessage val) =>
    try
      _steps(step_id)(msg)
    else
      _env.out.print("StepManager: Could not forward message")
    end

  be add_step(step_id: I32, computation_type: String) =>
    try
      let step = _step_lookup(computation_type)
      step.add_step_reporter(StepReporter(step_id, _metrics_collector))
      _steps(step_id) = step
    else
      _env.out.print("StepManager: Could not add step.")
    end

  be add_proxy(proxy_id: I32, step_id: I32, conn: TCPConnection tag) =>
    let p = Proxy(_env, step_id, conn, _metrics_collector)
    _steps(proxy_id) = p

  be add_sink(sink_id: I32, sink_step_id: I32, auth: AmbientAuth) =>
    try
      let sink_addr = _sink_addrs(sink_id)
      let sink_host = sink_addr._1
      let sink_service = sink_addr._2
      let conn = TCPConnection(auth, SinkConnectNotify(_env), sink_host,
        sink_service)
      _steps(sink_step_id) = _step_lookup.sink(conn, _metrics_collector)
    else
      _env.out.print("StepManager: Could not add sink.")
    end

  be connect_steps(in_id: I32, out_id: I32) =>
    try
      let input_step = _steps(in_id)
      let output_step = _steps(out_id)
      match input_step
      | let i: OutputStep tag =>
        i.add_output(output_step)
      else
        _env.out.print("StepManager: Could not connect steps")
      end
    end
