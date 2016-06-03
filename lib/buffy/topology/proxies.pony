use "collections"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "../network"
use "buffy/epoch"

actor Proxy is BasicStep
  let _env: Env
  let _auth: AmbientAuth
  let _node_name: String
  let _step_id: U64
  let _target_node_name: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector tag

  new create(env: Env, auth: AmbientAuth, node_name: String, step_id: U64,
    target_node_name: String, coordinator: Coordinator,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _auth = auth
    _node_name = node_name
    _step_id = step_id
    _target_node_name = target_node_name
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  // input will be a Message[In] once the typearg issue is fixed
  // ponyc #723
  be apply(input: StepMessage val) =>
    let forward = Forward(_step_id, _node_name, input)
    _coordinator.send_data_message(_target_node_name, forward)
    _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
      input.id(), input.last_ingress_ts(), Epoch.milliseconds())

actor StepManager
  let _env: Env
  let _auth: AmbientAuth
  let _node_name: String
  let _metrics_collector: MetricsCollector tag
  let _steps: Map[U64, BasicStep tag] = Map[U64, BasicStep tag]
  let _sink_addrs: Map[U64, (String, String)] val

  new create(env: Env, auth: AmbientAuth, node_name: String,
    sink_addrs: Map[U64, (String, String)] val,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _auth = auth
    _node_name = node_name
    _sink_addrs = sink_addrs
    _metrics_collector = metrics_collector

  be apply(step_id: U64, msg: StepMessage val) =>
    try
      _steps(step_id)(msg)
    else
      _env.out.print("StepManager: Could not forward message")
    end

  be add_step(step_id: U64, step_builder: BasicStepBuilder val) =>
    let step = step_builder()
    step.add_step_reporter(StepReporter(step_id, _metrics_collector))
    _steps(step_id) = step

  be add_proxy(proxy_step_id: U64, target_step_id: U64,
    target_node_name: String, coordinator: Coordinator) =>
    let p = Proxy(_env, _auth, _node_name, target_step_id, target_node_name,
      coordinator, _metrics_collector)
    _steps(proxy_step_id) = p

  be add_sink(sink_ids: Array[U64] val, sink_step_id: U64,
    sink_builder: SinkBuilder val, auth: AmbientAuth) =>
    try
      let conns: Array[TCPConnection] iso = recover Array[TCPConnection] end
      for sink_id in sink_ids.values() do
        let sink_addr = _sink_addrs(sink_id)
        let sink_host = sink_addr._1
        let sink_service = sink_addr._2
        let conn = TCPConnection(auth, SinkConnectNotify(_env), sink_host,
          sink_service)
        conns.push(conn)
      end
      _steps(sink_step_id) = sink_builder(consume conns, _metrics_collector)
    else
      _env.out.print("StepManager: Could not add sink. Did you supply enough"
      + " sink addresses?")
    end

  be connect_steps(in_id: U64, out_id: U64) =>
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
