use "collections"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "buffy/network"
use "sendence/epoch"

actor Proxy is BasicStep
  let _node_name: String
  let _step_id: U64
  let _target_node_name: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector tag

  new create(node_name: String, step_id: U64,
    target_node_name: String, coordinator: Coordinator,
    metrics_collector: MetricsCollector tag) =>
    _node_name = node_name
    _step_id = step_id
    _target_node_name = target_node_name
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64, 
    msg_data: D) =>
    _coordinator.send_data_message[D](_target_node_name, _step_id, _node_name, msg_id, source_ts, ingress_ts, msg_data)
    // _metrics_collector.report_boundary_metrics(BoundaryTypes.ingress_egress(),
    //   msg_id, ingress_ts, Epoch.nanoseconds())

actor StepManager
  let _env: Env
  let _node_name: String
  let _metrics_collector: MetricsCollector tag
  let _steps: Map[U64, BasicStep tag] = Map[U64, BasicStep tag]
  let _shared_state_steps: Map[U64, BasicSharedStateStep tag] 
    = Map[U64, BasicSharedStateStep tag]
  let _sink_addrs: Map[U64, (String, String)] val

  new create(env: Env, node_name: String,
    sink_addrs: Map[U64, (String, String)] val,
    metrics_collector: MetricsCollector tag) =>
    _env = env
    _node_name = node_name
    _sink_addrs = sink_addrs
    _metrics_collector = metrics_collector

  fun lookup(i: U64): BasicStep tag ? => _steps(i) 

  be send[D: Any val](step_id: U64, msg_id: U64, source_ts: U64, 
    ingress_ts: U64, msg_data: D) 
  =>
    try
      _steps(step_id).send[D](msg_id, source_ts, ingress_ts, msg_data)
    else
      _env.out.print("StepManager: Could not forward message")
    end

  be initialize_source(source_id: U64, pipeline: PipelineSteps val, 
    target_id: U64, host: String, service: String,
    local_step_builder: (LocalStepBuilder val | None),
    coordinator: Coordinator tag) =>
    try
      let target_step = _steps(target_id)
      let shared_state = 
        try
          let l = local_step_builder as LocalStepBuilder val
          let state_id = l.state_id() as U64
          let ss = _shared_state_steps(state_id)
          ss
        else
          None 
        end
      let auth = _env.root as AmbientAuth
      pipeline.initialize_source(source_id, host, service, 
        _env, auth, coordinator, target_step, local_step_builder,
        shared_state) 
    else
      _env.err.print("StepManager: Could not initialize source")
    end

  be passthrough_to_step[D: Any val](step_id: U64, 
    passthrough: BasicOutputStep tag) =>
    try
      let step = _steps(step_id) 
      match passthrough
      | let p: PassThrough tag =>   
        p.add_output_and_send[D](step)
      end
    else
      _env.err.print("StepManager: Error setting up passthrough.")
    end

  be add_step(step_id: U64, step_builder: BasicStepBuilder val) =>
    let step = step_builder()
    match step
    | let s: StepManaged tag =>
      s.add_step_manager(this)
    end
    step.add_step_reporter(StepReporter(step_id, step_builder.name(), 
      _metrics_collector))
    _steps(step_id) = step

  be add_shared_state_step(step_id: U64, 
    step_builder: BasicSharedStateStepBuilder val) =>
    if not _shared_state_steps.contains(step_id) then
      let step = step_builder()
      _shared_state_steps(step_id) = step
    end

  be add_partition_step_and_ack(step_id: U64,
    partition_id: U64, partition_report_id: U64, 
    step_builder: BasicStepBuilder val, partition: PartitionAckable tag) 
  =>
    let step = step_builder()
    match step
    | let s: StepManaged tag =>
      s.add_step_manager(this)
    end
    step.add_step_reporter(StepReporter(partition_report_id, 
      step_builder.name(), _metrics_collector))
    _steps(step_id) = step
    partition.ack(partition_id, step_id)

  be add_initial_state[State: Any #read](step_id: U64,
    state: {(): State} val) =>
    try
      match _shared_state_steps(step_id)
      | let step: SharedStateStep[State] tag =>
        step.update_state(state)
      end
    end

  be add_proxy(proxy_step_id: U64, target_step_id: U64,
    target_node_name: String, coordinator: Coordinator) =>
    let p = Proxy(_node_name, target_step_id, target_node_name,
      coordinator, _metrics_collector)
    _steps(proxy_step_id) = p

  be connect_to_state(shared_state_step_id: U64, 
    state_step: BasicStateStep tag) =>
    try
      let shared_state_step = _shared_state_steps(shared_state_step_id)
      state_step.add_shared_state(shared_state_step)
    end

  be add_state_step(step_id: U64, bssb: BasicStateStepBuilder val,
    shared_state_step_id: U64, shared_state_step_node: String,
    coordinator: Coordinator)
  =>
    if not _shared_state_steps.contains(shared_state_step_id) then
      add_proxy(shared_state_step_id, shared_state_step_id,
        shared_state_step_node, coordinator)
    end

    let step: BasicStep tag = bssb()
    step.add_step_reporter(StepReporter(step_id, bssb.name(), 
      _metrics_collector))
    try
      let shared_state_step = _shared_state_steps(shared_state_step_id)
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
      let sink = sink_builder(consume conns, _metrics_collector)
      _steps(sink_step_id) = sink
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
