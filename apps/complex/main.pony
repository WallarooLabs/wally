use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "sendence/hub"
use "sendence/fix"
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
    output_addr: Array[String], metrics_addr: Array[String], 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (Initializer | None)) ? 
  =>
    // Complex numbers app
    // Complex number -> Get conjugate -> Scale by 5

    let auth = env.root as AmbientAuth

    let jr_metrics = JrMetrics("Complex Numbers")

    let connect_auth = TCPConnectAuth(auth)
    let metrics_conn = TCPConnection(connect_auth,
          OutNotify("metrics"),
          metrics_addr(0),
          metrics_addr(1))
    let connect_msg = HubProtocol.connect()
    let metrics_join_msg = HubProtocol.join("metrics:complex-numbers")
    metrics_conn.writev(connect_msg)
    metrics_conn.writev(metrics_join_msg)

    if worker_count == 1 then
      let reports_socket = TCPConnection(connect_auth,
        OutNotify("results"),
        output_addr(0),
        output_addr(1))
      let reports_join_msg = HubProtocol.join("reports:complex-numbers")
      reports_socket.writev(connect_msg)
      reports_socket.writev(reports_join_msg)

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

      // determine layout
      let topology_starter = ComplexTopologyStarter((output_addr(0), 
        output_addr(1)), metrics_conn)

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
  let _output_addr: (String, String)
  let _metrics_conn: TCPConnection

  new val create(output_addr: (String, String),
    metrics_conn: TCPConnection) =>
    _output_addr = output_addr
    _metrics_conn = metrics_conn

  fun apply() =>
    let scale_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Scale end,
      _metrics_conn, "complex-numbers")

    let conjugate_builder = GeneralStepBuilder[Complex val, Complex val](
      lambda(): Computation[Complex val, Complex val] val => Conjugate end,
      _metrics_conn, "complex-numbers")

    let worker_2_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_2_builders.push(conjugate_builder) 

    let worker_3_builders: Array[StepBuilder val] trn = 
      recover Array[StepBuilder val] end

    worker_3_builders.push(scale_builder)


    let worker_2_topology = LocalTopology(consume worker_2_builders,
      2)

    let worker_3_topology = LocalTopology(consume worker_3_builders,
      _output_addr)

    @printf[I32]("Topology starter has run!\n".cstring())

class GeneralStepBuilder[In: Any val, Out: Any val]
  let _metrics_conn: TCPConnection
  let _computation_builder: {(): Computation[In, Out] val} val
  let _pipeline_name: String 

  new val create(c: {(): Computation[In, Out] val} val,
    metrics_conn: TCPConnection,
    pipeline_name: String) =>
    _metrics_conn = metrics_conn
    _computation_builder = c
    _pipeline_name = pipeline_name

  fun apply(target: Step tag): Step tag =>
    let reporter = MetricsReporter(_pipeline_name, _metrics_conn)
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

