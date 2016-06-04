use "collections"
use "debug"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "sendence/guid"
use "../network"
use "time"

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
      input.id(), input.last_ingress_ts(), Time.millis())

actor StepManager
  let _env: Env
  let _auth: AmbientAuth
  let _node_name: String
  let _metrics_collector: MetricsCollector tag
  let _steps: Map[U64, BasicStep tag] = Map[U64, BasicStep tag]
  let _sink_addrs: Map[U64, (String, String)] val
  let _guid_gen: GuidGenerator = GuidGenerator

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
    match step
    | let s: StepManaged tag =>
      s.add_step_manager(this)
    end
    step.add_step_reporter(StepReporter(step_id, _metrics_collector))
    _steps(step_id) = step

  be add_partition_step_and_ack(step_id: U64, partition_id: U64,
    step_builder: BasicStepBuilder val, partition: PartitionAckable tag) =>
    let step = step_builder()
    match step
    | let s: StepManaged tag =>
      s.add_step_manager(this)
    end
    step.add_step_reporter(StepReporter(step_id, _metrics_collector))
    _steps(step_id) = step
    partition.ack(partition_id, step_id)

  be add_proxy(proxy_step_id: U64, target_step_id: U64,
    target_node_name: String, coordinator: Coordinator) =>
    let p = Proxy(_env, _auth, _node_name, target_step_id, target_node_name,
      coordinator, _metrics_collector)
    _steps(proxy_step_id) = p

  be connect_to_state(state_step_id: U64, state_step: BasicStateStep tag) =>
    try
      let shared_state_step = _steps(state_step_id)
      state_step.add_shared_state(shared_state_step)
    end

  be add_state_step(step_id: U64, bssb: BasicStateStepBuilder val,
    shared_state_step_id: U64, shared_state_step_node: String,
    coordinator: Coordinator) =>
    if not _steps.contains(shared_state_step_id) then
      add_proxy(shared_state_step_id, shared_state_step_id,
        shared_state_step_node, coordinator)
    end

    let step: BasicStep tag = bssb()
    step.add_step_reporter(StepReporter(step_id, _metrics_collector))
    try
      let shared_state_step = _steps(shared_state_step_id)
      match step
      | let s: BasicStateStep tag =>
        s.add_shared_state(shared_state_step)
      end
    end
    _steps(step_id) = step

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
      | let i: BasicOutputStep tag =>
        i.add_output(output_step)
      else
        _env.out.print("StepManager: Could not connect steps")
      end
    else
      _env.out.print("StepManager: Failed to connect steps")
    end

  be add_output_to(in_id: U64, output: BasicStep tag) =>
    try
      let input_step = _steps(in_id)
      match input_step
      | let i: BasicOutputStep tag =>
        i.add_output(output)
      else
        _env.out.print("StepManager: Could not add output to step")
      end
    else
      _env.out.print("StepManager: Failed to add output to step")
    end
