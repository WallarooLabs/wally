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
  fun apply(env: Env, input_addrs: Array[Array[String]], 
    output_addr: Array[String], metrics_addr: Array[String], 
    expected: USize, init_path: String, worker_count: USize,
    initializer: Bool) ? 
  =>
    let auth = env.root as AmbientAuth

    let jr_metrics = JrMetrics("Complex Numbers")

    let connect_auth = TCPConnectAuth(auth)
    let metrics_socket = TCPConnection(connect_auth,
          OutNotify("metrics"),
          metrics_addr(0),
          metrics_addr(1))
    let connect_msg = HubProtocol.connect()
    let metrics_join_msg = HubProtocol.join("metrics:complex-numbers")
    metrics_socket.writev(connect_msg)
    metrics_socket.writev(metrics_join_msg)

    let reports_socket = TCPConnection(connect_auth,
      OutNotify("results"),
      output_addr(0),
      output_addr(1))
    let reports_join_msg = HubProtocol.join("reports:complex-numbers")
    reports_socket.writev(connect_msg)
    reports_socket.writev(reports_join_msg)

    let complex_source_builder: {(): Source iso^} val = 
      recover 
        lambda()(metrics_socket): Source iso^ 
        =>
          let complex_reporter = MetricsReporter("complex-numbers",
            metrics_socket)
          let runner = ComputationRunner[Complex val, Complex val](Conjugate, 
            Step(SimpleSink), consume complex_reporter)
          let step = Step(consume runner)
          let router = DirectRouter[Complex val, Step tag](step) 
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

