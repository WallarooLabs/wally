use "collections"
use "debug"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "../network"
use "time"

actor Proxy is BasicStep
  let _env: Env
  let _node_name: String
  let _step_id: I32
  let _target_node_name: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector tag

  new create(env: Env, node_name: String, step_id: I32, target_node_name: String,
    coordinator: Coordinator, metrics_collector: MetricsCollector tag) =>
    _env = env
    _node_name = node_name
    _step_id = step_id
    _target_node_name = target_node_name
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  // input will be a Message[In] once the typearg issue is fixed
  // ponyc #723
  be apply(input: StepMessage val) =>
    match input
    | let m: Message[I32] val =>
      let tcp_msg = WireMsgEncoder.forward_i32(_step_id, _node_name, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _coordinator.send_data_message(_target_node_name, tcp_msg)
    | let m: Message[F32] val =>
      let tcp_msg = WireMsgEncoder.forward_f32(_step_id, _node_name, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _coordinator.send_data_message(_target_node_name, tcp_msg)
    | let m: Message[String] val =>
      let tcp_msg = WireMsgEncoder.forward_string(_step_id, _node_name, m)
      _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
        m.id, m.last_ingress_ts, Time.millis())
      _coordinator.send_data_message(_target_node_name, tcp_msg)
    end

actor StepManager
  let _env: Env
  let _node_name: String
  let _metrics_collector: MetricsCollector tag
  let _steps: Map[I32, BasicStep tag] = Map[I32, BasicStep tag]
  let _sink_addrs: Map[I32, (String, String)] val
  let _step_lookup: StepLookup val

  new create(env: Env, node_name: String, step_lookup: StepLookup val,
    sink_addrs: Map[I32, (String, String)] val,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _node_name = node_name
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

  be add_proxy(proxy_step_id: I32, target_step_id: I32,
    target_node_name: String, coordinator: Coordinator) =>
    let p = Proxy(_env, _node_name, target_step_id, target_node_name, coordinator,
      _metrics_collector)
    _steps(proxy_step_id) = p

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
    else
      _env.out.print("StepManager: Failed to connect steps")
    end
