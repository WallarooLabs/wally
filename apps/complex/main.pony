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
      reports_conn.writev(connect_msg)
      reports_conn.writev(reports_join_msg)

      let sink_reporter = MetricsReporter("complex-numbers", metrics_conn)
      let sink = Step(SimpleSink(consume sink_reporter))
      let scale_reporter = MetricsReporter("complex-numbers", metrics_conn)
      let scale_runner = ComputationRunner[Complex val, Complex val](Scale,
        sink, consume scale_reporter)
      let scale_step = Step(consume scale_runner)

      let complex_source_builder: {(): Source iso^} val = 
        recover 
          lambda()(metrics_conn, scale_step): Source iso^ 
          =>
            let complex_reporter = MetricsReporter("complex-numbers",
              metrics_conn)
            let runner = ComputationRunner[Complex val, Complex val](Conjugate,
              scale_step, consume complex_reporter)
            let conjugate_step = Step(consume runner)
            let router = DirectRouter[Complex val, Step tag](conjugate_step) 
            StatelessSource[Complex val]("Complex Numbers Source",
              ComplexSourceParser, consume router)
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

    let complex_source_builder: {(): Source iso^} val = 
      recover 
        lambda()(proxy_step): Source iso^ 
        =>
          let router = DirectRouter[Complex val, Step tag](proxy_step) 
          StatelessSource[Complex val]("Complex Numbers",
            ComplexSourceParser, consume router)
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
    let conjugate_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Conjugate end,
      pipeline_name, conjugate_step_id)

    let scale_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Scale end,
      pipeline_name, scale_step_id)

    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_builder) 
    worker_2_builders.push(scale_builder) 

    let worker_2_topology = LocalTopology(pipeline_name, consume worker_2_builders where global_sink = _output_addr)

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
    let conjugate_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Conjugate end,
      pipeline_name, conjugate_step_id)

    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_builder) 

    // Worker 3
    let scale_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Scale end,
      pipeline_name, scale_step_id)

    let worker_3_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_3_builders.push(scale_builder)

    let worker_2_topology = LocalTopology(pipeline_name, consume worker_2_builders
      where local_sink = ProxyAddress(worker3, scale_step_id))

    let worker_3_topology = LocalTopology(pipeline_name, consume worker_3_builders
      where global_sink = _output_addr)

    let local_topologies: Array[LocalTopology val] trn = 
      recover Array[LocalTopology val] end
    local_topologies.push(worker_2_topology)
    local_topologies.push(worker_3_topology)

    consume local_topologies 

class GeneralStepBuilder[In: Any val, Out: Any val]
  let _computation_builder: {(): Computation[In, Out] val} val
  let _pipeline_name: String 
  let _id: U128

  new val create(c: {(): Computation[In, Out] val} val,
    pipeline_name: String, id': U128) =>
    _computation_builder = c
    _pipeline_name = pipeline_name
    _id = id'

  fun id(): U128 => _id

  fun apply(target: Step tag, metrics_conn: TCPConnection): Step tag =>
    let reporter = MetricsReporter(_pipeline_name, metrics_conn)
    let runner = ComputationRunner[In, Out](
      _computation_builder(), target, consume reporter)    
    Step(consume runner)



// class val ConjugateStepBuilder
//   let _metrics_builder: {(): MetricsReporter iso} val
//   let _computation_builder: {(): Computation[Complex val, Complex val]} val

//   new create(m: {(): MetricsReporter iso} val, 
//     c: {(): Computation[Complex val, Complex val]} val) =>
//     _metrics_builder = m
//     _computation_builder = c

//   fun apply(target: Step tag): Step tag =>
//     let scale_reporter = MetricsReporter("complex-numbers", metrics_conn)
//     let conjugate_runner = ComputationRunner[Complex val, Complex val](Conjugate,
//       target, _metrics_builder())    
//     Step(consume conjugate_runner)

// class val ScaleStepBuilder
//   let _metrics_builder: {(): MetricsReporter iso} val
//   let _computation_builder: {(): Computation[Complex val, Complex val]} val

//   new create(m: {(): MetricsReporter iso} val, 
//     c: {(): Computation[Complex val, Complex val]} val) =>
//     _metrics_builder = m
//     _computation_builder = c

//   fun apply(target: Step tag): Step tag =>
//     let scale_reporter = MetricsReporter("complex-numbers", metrics_conn)
//     let scale_runner = ComputationRunner[Complex val, Complex val](Scale,
//       target, _metrics_builder())    
//     Step(consume scale_runner)    

