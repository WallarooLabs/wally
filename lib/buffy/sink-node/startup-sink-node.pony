use "options"
use "net"
use "buffy"

class StartupSinkNode

  new create(env: Env, sink_builders: Array[SinkNodeStepBuilder val] val) =>
    let options = Options(env.args, false)
    var addr = Array[String]
    var phone_home_addr: (Array[String] | None) = None
    var target_addr = Array[String]
    var step_builder_idx: I64 = 0
    var name: String = ""

    options
      .add("run-sink", "", None)
      .add("listen", "l", StringArgument)
      .add("target-addr", "t", StringArgument)
      .add("step-builder", "s", I64Argument)
      .add("metrics-receiver", "r", None)
      .add("name", "n", StringArgument)
      .add("phone-home", "p", StringArgument)
      .add("help", "h", None)

    for option in options do
      match option
      | ("run-sink", None) => None
      | ("listen", let arg: String) => addr = arg.split(":")
      | ("target-addr", let arg: String) => target_addr = arg.split(":")
      | ("step-builder", let arg: I64) => step_builder_idx = arg
      | ("phone-home", let arg: String) => phone_home_addr = arg.split(":")
      | ("name", let arg: String) => name = arg
      | ("help", None) =>
        // StartupHelp.sink_node(env)
        return
      end
    end

    try
      if name == "" then
        // StartupHelp.sink_node(env)
        env.err.print("You must provide a name (--name/-n)\n")
        return
      end

      if sink_builders.size() == 0 then
        env.err.print("This app is not configured to use a sink node")
        return
      end

      let coordinator = SinkNodeCoordinatorFactory(env, name,
        phone_home_addr)

      let sink_builder = sink_builders(step_builder_idx.usize())
      let auth = env.root as AmbientAuth

      let host = addr(0)
      let service = addr(1)

      let target_host = target_addr(0)
      let target_service = target_addr(1)

      let notifier = SinkNodeOutConnectNotify(env, coordinator)
      let out_conn = TCPConnection(auth, consume notifier,
        target_host, target_service)

      let sink_node_step = sink_builder(out_conn)

      TCPListener(auth, SinkNodeNotifier(env, auth, sink_node_step, host,
        service, coordinator), host, service)
      // StartupHelp.sink_node(env)
    end
