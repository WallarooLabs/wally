type StepInitializer is (StepBuilder | PartitionedPreStateStepBuilder | EgressBuilder)

class StepBuilder
  let _runner_builder: RunnerBuilder val
  let _id: U128
  let _is_stateful: Bool

  new val create(r: RunnerBuilder val, id': U128,
    is_stateful': Bool = false) 
  =>    
    _runner_builder = r
    _id = id'
    _is_stateful = is_stateful'

  fun name(): String => _runner_builder.name()
  fun id(): U128 => _id
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String, alfred: Alfred, router: Router val = EmptyRouter): 
      Step tag 
  =>
    let runner = _runner_builder(MetricsReporter(pipeline_name, 
      metrics_conn) where alfred = alfred, router = router)
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn), router)
    step.update_router(next)
    step

class PartitionedPreStateStepBuilder
  let _pre_state_subpartition: PreStateSubpartition val
  let _runner_builder: RunnerBuilder val
  let _state_name: String

  new val create(sub: PreStateSubpartition val, r: RunnerBuilder val, 
    state_name': String) 
  =>
    _pre_state_subpartition = sub
    _runner_builder = r
    _state_name = state_name'

  fun name(): String => _runner_builder.name() + " partition"
  fun state_name(): String => _state_name
  fun id(): U128 => 0
  fun is_stateful(): Bool => true
  fun is_partitioned(): Bool => true
  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String, alfred: Alfred, router: Router val = EmptyRouter): 
      Step tag 
  =>
    Step(RouterRunner, MetricsReporter(pipeline_name, metrics_conn))

  fun build_partition(worker_name: String, state_addresses: StateAddresses val,
    metrics_conn: TCPConnection, auth: AmbientAuth, connections: Connections, 
    alfred: Alfred, state_comp_router: Router val = EmptyRouter): 
      PartitionRouter val 
  =>
    _pre_state_subpartition.build(worker_name, _runner_builder, 
      state_addresses, metrics_conn, auth, connections, alfred,
      state_comp_router)

class EgressBuilder
  let _name: String
  let _id: U128
  let _addr: (Array[String] val | ProxyAddress val)
  let _sink_builder: (TCPSinkBuilder val | None)

  new val create(pipeline_name: String, id': U128,
    addr: (Array[String] val | ProxyAddress val), 
    sink_builder: (TCPSinkBuilder val | None) = None)
  =>
    _name = 
      match addr
      | let pa: ProxyAddress val =>
        "Proxy to " + pa.worker
      else
        pipeline_name + " sink"
      end

    _id = id'
    _addr = addr
    _sink_builder = sink_builder

  fun name(): String => _name
  fun id(): U128 => _id
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false

  fun apply(worker_name: String, reporter: MetricsReporter iso, 
    auth: AmbientAuth,
    proxies: Map[String, Array[Step tag]] = Map[String, Array[Step tag]]): 
    RunnableStep tag ?
  =>    
    match _addr
    | let a: Array[String] val =>
      try
        match _sink_builder
        | let tsb: TCPSinkBuilder val =>
          @printf[I32](("Connecting to sink at " + a(0) + ":" + a(1) + "\n").cstring())

          tsb(reporter.clone(), a(0), a(1))
        else
          EmptySink
        end
      else
        @printf[I32]("Error connecting to sink.\n".cstring())
        error
      end
    | let p: ProxyAddress val =>
      @printf[I32](("Creating Proxy to " + p.worker + "\n").cstring())
      let proxy = Proxy(worker_name, p.step_id, reporter.clone(), auth)
      let proxy_step = Step(consume proxy, consume reporter)
      if proxies.contains(worker_name) then
        proxies(p.worker).push(proxy_step)
      else
        proxies(p.worker) = Array[Step tag]
        proxies(p.worker).push(proxy_step)
      end
      proxy_step
    else
      // The match is exhaustive, so this can't happen
      @printf[I32]("Exhaustive match failed somehow\n".cstring())
      error
    end 