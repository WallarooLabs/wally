use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "sendence/hub"
use "sendence/fix"
use "sendence/guid"
use "wallaroo"
use "wallaroo/network"
use "wallaroo/metrics"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    Startup(env, ComplexStarter)

primitive ComplexStarter
  fun apply(env: Env, initializer_data_addr: Array[String],
    input_addrs: Array[Array[String]], 
    output_addr: Array[String], metrics_conn: TCPConnection, 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (Initializer | None)) ? 
  =>
    // Complex numbers app
    // Complex number -> Get conjugate -> Scale by 5

    let auth = env.root as AmbientAuth

    let jr_metrics = JrMetrics("Complex Numbers")

    let connect_auth = TCPConnectAuth(auth)

    // Set up metrics
    let connect_msg = HubProtocol.connect()
    let metrics_join_msg = HubProtocol.join("metrics:complex-numbers")
    metrics_conn.writev(connect_msg)
    metrics_conn.writev(metrics_join_msg)

    if worker_count == 1 then
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
      let nbbo = TCPListener(listen_auth,
            SourceListenerNotify(complex_source_builder, jr_metrics, expected),
            source_addr(0),
            source_addr(1))
    elseif is_initializer then
      @printf[I32](("I'm " + worker_name + ", the Initializer!\n").cstring())

      // setup control and data channels

      // setup local data channel

      let data_notifier: TCPListenNotify iso =
        DataChannelListenNotifier(worker_name, env, auth, connections, 
          is_initializer)

      let d_host = initializer_data_addr(0)
      let d_service = initializer_data_addr(1)
      TCPListener(auth, consume data_notifier, d_host, d_service)

      let sendable_output_addr: Array[String] trn = recover Array[String] end
      sendable_output_addr.push(output_addr(0)) 
      sendable_output_addr.push(output_addr(1)) 

      // determine layout
      let topology_starter = ComplexTopologyStarter(
        consume sendable_output_addr, metrics_conn)

      match initializer
      | let init: Initializer =>
        init.start(topology_starter)
      end

      // wait for all workers to connect

      // inform workers of each other

      // tell workers what to spin up and how to connect
    else
      @printf[I32](("I'm " + worker_name + " and I'm not the initializer!\n").cstring())

      // set up control and data listeners
    end

class ComplexTopologyStarter is TopologyStarter
  let _output_addr: Array[String] val
  let _metrics_conn: TCPConnection

  new val create(output_addr: Array[String] val,
    metrics_conn: TCPConnection) =>
    _output_addr = output_addr
    _metrics_conn = metrics_conn

  fun apply(initializer: Initializer) =>
    let pipeline_name = "complex-numbers"
    let guid_gen = GuidGenerator

    let scale_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Scale end,
      pipeline_name, guid_gen.u128())

    let conjugate_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Conjugate end,
      pipeline_name, guid_gen.u128())

    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_builder) 

    let worker_3_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_3_builders.push(scale_builder)


    let worker_2_topology = LocalTopology(pipeline_name, consume worker_2_builders
      where local_sink = 2)

    let worker_3_topology = LocalTopology(pipeline_name, consume worker_3_builders
      where global_sink = _output_addr)

    let local_topologies: Array[LocalTopology val] trn = 
      recover Array[LocalTopology val] end
    local_topologies.push(worker_2_topology)
    local_topologies.push(worker_3_topology)

    @printf[I32]("Topology starter has run!\n".cstring())

    initializer.distribute_local_topologies(consume local_topologies)

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

