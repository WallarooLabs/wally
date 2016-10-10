use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "sendence/hub"
use "sendence/fix"
use "sendence/guid"
use "sendence/messages"
use "wallaroo"
use "wallaroo/network"
use "wallaroo/metrics"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    Startup(env, ComplexStarter)

primitive ComplexStarter
  fun apply(env: Env, initializer_data_addr: Array[String],
    input_addrs: Array[Array[String]] val, 
    output_addr: Array[String], metrics_conn: TCPConnection, 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (Initializer | None)) ? 
  =>
    // Complex numbers app
    // Complex number -> Scale by 3 -> Get conjugate -> Scale by 5

    let auth = env.root as AmbientAuth


    let connect_auth = TCPConnectAuth(auth)

    // Set up metrics
    let connect_msg = HubProtocol.connect()
    let metrics_join_msg = HubProtocol.join("metrics:complex-numbers")
    metrics_conn.writev(connect_msg)
    metrics_conn.writev(metrics_join_msg)

    if worker_count == 1 then
      let jr_metrics = JrMetrics("Complex Numbers")

      let reports_conn = TCPConnection(connect_auth,
        OutNotify("results"),
        output_addr(0),
        output_addr(1))
      let reports_join_msg = HubProtocol.join("reports:complex-numbers")

      let sink_reporter = MetricsReporter("complex-numbers", metrics_conn)
      let sink = Step(SimpleSinkRunner(consume sink_reporter))
      let sink_router = DirectRouter(sink)

      let scale_reporter = MetricsReporter("complex-numbers", metrics_conn)
      let scale_runner = ComputationRunner[Complex val, Complex val](Scale,
        RouterRunner, consume scale_reporter)
      let scale_step = Step(consume scale_runner)
      scale_step.update_router(sink_router)
      let scale_step_router = DirectRouter(scale_step)

      let complex_source_builder: {(): Source[Complex val] iso^} val = 
        recover 
          lambda()(metrics_conn, scale_step_router): Source[Complex val] iso^ 
          =>
            let complex_reporter = MetricsReporter("complex-numbers",
              metrics_conn)
            let conjugate_runner = ComputationRunner[Complex val, Complex val](
              Conjugate, RouterRunner, complex_reporter.clone())
            let conjugate_step = Step(consume conjugate_runner)
            conjugate_step.update_router(scale_step_router)
            let conjugate_router = DirectRouter(conjugate_step) 

            Source[Complex val]("Complex Numbers", ComplexSourceDecoder, 
              RouterRunnerBuilder, conjugate_router, consume complex_reporter)
          end
        end

      let source_addr = input_addrs(0)

      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      connections.register_listener(
        TCPListener(listen_auth,
          SourceListenerNotify(complex_source_builder, jr_metrics, expected),
          source_addr(0),
          source_addr(1))
      )
      
      let topology_ready_msg = 
        ExternalMsgEncoder.topology_ready("initializer")
      connections.send_phone_home(topology_ready_msg)
      @printf[I32]("Sent TopologyReady\n".cstring())
    elseif is_initializer then
      @printf[I32](("I'm " + worker_name + ", the Initializer!\n").cstring())

      let data_notifier: TCPListenNotify iso =
        DataChannelListenNotifier(worker_name, env, auth, connections, 
          is_initializer)

      let d_host = initializer_data_addr(0)
      let d_service = initializer_data_addr(1)
      connections.register_listener(
        TCPListener(auth, consume data_notifier, d_host, d_service)
      )

      let sendable_output_addr: Array[String] trn = recover Array[String] end
      sendable_output_addr.push(output_addr(0)) 
      sendable_output_addr.push(output_addr(1)) 

      // determine layout
      let topology_starter = ComplexTopologyStarter(
        consume sendable_output_addr, metrics_conn, auth)

      match initializer
      | let init: Initializer =>
        init.start(topology_starter)
      end
    else
      @printf[I32](("I'm " + worker_name + " and I'm not the initializer!\n").cstring())
    end

class ComplexTopologyStarter is TopologyStarter
  let _output_addr: Array[String] val
  let _metrics_conn: TCPConnection
  let _auth: AmbientAuth

  new val create(output_addr: Array[String] val,
    metrics_conn: TCPConnection, auth: AmbientAuth) =>
    _output_addr = output_addr
    _metrics_conn = metrics_conn
    _auth = auth

  fun apply(initializer: Initializer, workers: Array[String] box,
    input_addrs: Array[Array[String]] val, expected: USize) ? =>
    let pipeline_name = "complex-numbers"
    let guid_gen = GuidGenerator
    let conjugate_step_id = guid_gen.u128()
    let scale_step_id = guid_gen.u128()
    let worker2 = workers(0)

    let local_topologies =
      if workers.size() == 1 then
        create_local_topologies_for_2(pipeline_name, conjugate_step_id, 
          scale_step_id, workers)
      elseif workers.size() == 2 then 
        create_local_topologies_for_3(pipeline_name, conjugate_step_id, 
          scale_step_id, workers)
      else
        @printf[I32]("Complex app only works with 1-3 workers!\n".cstring())
        error
      end

    @printf[I32]("Topology starter has run!\n".cstring())

    initializer.distribute_local_topologies(local_topologies)

    // Configure local topology on initializer, including source
    let sink_reporter = MetricsReporter(pipeline_name, _metrics_conn)

    let proxy = Proxy("initializer", conjugate_step_id, consume sink_reporter, _auth)
    let proxy_step = Step(consume proxy)

    initializer.register_proxy(worker2, proxy_step)

    let complex_source_builder: {(): Source[Complex val] iso^} val = 
      recover 
        lambda()(proxy_step, _metrics_conn): Source[Complex val] iso^ 
        =>
          let complex_reporter = MetricsReporter("complex-numbers",
            _metrics_conn)
          let proxy_router = DirectRouter(proxy_step) 
          Source[Complex val]("Complex Numbers", ComplexSourceDecoder, 
            RouterRunnerBuilder, proxy_router, consume complex_reporter)
        end
      end

    let source_addr = input_addrs(0)

    let jr_metrics = JrMetrics("Complex Numbers")

    let listen_auth = TCPListenAuth(_auth)
    TCPListener(listen_auth,
      SourceListenerNotify(complex_source_builder, jr_metrics, expected),
      source_addr(0),
      source_addr(1)) 

    @printf[I32]("Finished running startup code!\n".cstring())   

  fun create_local_topologies_for_2(pipeline_name: String, 
    conjugate_step_id: U128, scale_step_id: U128, workers: Array[String] box): 
    Array[LocalTopology val] val ?
  =>
    let worker2 = workers(0) 

    // Worker 1 (self)
    let worker_1_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    // Worker 2
    let conjugate_builder = lambda(): Computation[Complex val, Complex val] val => Conjugate end

    let conjugate_runner_builders: Array[RunnerBuilder val] trn = recover
      Array[RunnerBuilder val] end

    conjugate_runner_builders.push(ComputationRunnerBuilder[Complex val,
      Complex val](conjugate_builder))

    let conjugate_step_builder = StatelessStepBuilder(
      RunnerSequenceBuilder(consume conjugate_runner_builders),
      conjugate_step_id)


    let scale_builder = lambda(): Computation[Complex val, Complex val] val => Scale end

    let scale_runner_builders: Array[RunnerBuilder val] trn = recover
      Array[RunnerBuilder val] end

    scale_runner_builders.push(ComputationRunnerBuilder[Complex val,
      Complex val](scale_builder))

    let scale_step_builder = StatelessStepBuilder(
      RunnerSequenceBuilder(consume scale_runner_builders), scale_step_id)


    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_step_builder) 
    worker_2_builders.push(scale_step_builder) 

    let sink_runner_builder = EncoderSinkRunnerBuilder[Complex val](
      pipeline_name, ComplexEncoder)

    let egress_builder = EgressBuilder(_output_addr, sink_runner_builder)

    let worker_2_pipelines: Array[LocalPipeline val] trn = recover
      Array[LocalPipeline val] end

    worker_2_pipelines.push(LocalPipeline(pipeline_name, 
      consume worker_2_builders, egress_builder))

    let worker_2_topology = LocalTopology("complex numbers", 
      consume worker_2_pipelines)

    let local_topologies: Array[LocalTopology val] trn = 
      recover Array[LocalTopology val] end
    local_topologies.push(worker_2_topology)

    consume local_topologies

  fun create_local_topologies_for_3(pipeline_name: String, 
    conjugate_step_id: U128, scale_step_id: U128, workers: Array[String] box): 
    Array[LocalTopology val] val ?
  =>
    let guid_gen = GuidGenerator

    let worker2 = workers(0) 
    let worker3 = workers(1) 

    // Worker 1 (self)
    let worker_1_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    // Worker 2
    let conjugate_builder = lambda(): Computation[Complex val, Complex val] val => Conjugate end

    let conjugate_runner_builders: Array[RunnerBuilder val] trn = recover
      Array[RunnerBuilder val] end

    conjugate_runner_builders.push(ComputationRunnerBuilder[Complex val,
      Complex val](conjugate_builder))

    let conjugate_step_builder = StatelessStepBuilder(
      RunnerSequenceBuilder(consume conjugate_runner_builders),
      conjugate_step_id)


    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_step_builder) 

    // Worker 3
    let scale_builder = lambda(): Computation[Complex val, Complex val] val => Scale end

    let scale_runner_builders: Array[RunnerBuilder val] trn = recover
      Array[RunnerBuilder val] end

    scale_runner_builders.push(ComputationRunnerBuilder[Complex val,
      Complex val](scale_builder))

    let scale_step_builder = StatelessStepBuilder(
      RunnerSequenceBuilder(consume scale_runner_builders), scale_step_id)

    let worker_3_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_3_builders.push(scale_step_builder)


    let sink_runner_builder = EncoderSinkRunnerBuilder[Complex val](
      pipeline_name, ComplexEncoder)

    let worker_3_egress_builder = EgressBuilder(_output_addr, 
      sink_runner_builder)

    let worker_3_pipelines: Array[LocalPipeline val] trn = recover
      Array[LocalPipeline val] end

    worker_3_pipelines.push(LocalPipeline(pipeline_name, 
      consume worker_3_builders, worker_3_egress_builder))



    let worker_2_egress_builder = EgressBuilder(
      ProxyAddress(worker3, scale_step_id), sink_runner_builder)

    let worker_2_pipelines: Array[LocalPipeline val] trn = recover
      Array[LocalPipeline val] end

    worker_2_pipelines.push(LocalPipeline(pipeline_name, 
      consume worker_2_builders, worker_2_egress_builder))


    let worker_2_topology = LocalTopology(pipeline_name, consume worker_2_pipelines)

    let worker_3_topology = LocalTopology(pipeline_name, consume worker_3_pipelines)

    let local_topologies: Array[LocalTopology val] trn = 
      recover Array[LocalTopology val] end
    local_topologies.push(worker_2_topology)
    local_topologies.push(worker_3_topology)

    consume local_topologies 

