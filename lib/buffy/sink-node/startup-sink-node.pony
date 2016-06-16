use "options"
use "net"
use "buffy/metrics/receiver"

class StartupSinkNode

  new create(env: Env, sink_builders: Array[SinkNodeStepBuilder val] val) =>
    let options = Options(env)
    var addr = Array[String]
    var target_addr = Array[String]
    var step_builder_idx: I64 = 0
    var is_metrics_receiver = false

    options
      .add("run-sink", "", None)
      .add("addr", "a", StringArgument)
      .add("target-addr", "t", StringArgument)
      .add("step-builder", "s", I64Argument)
      .add("metrics-receiver", "m", None)

    for option in options do
      match option
      | ("run-sink", None) => None
      | ("addr", let arg: String) => addr = arg.split(":")
      | ("target-addr", let arg: String) => target_addr = arg.split(":")
      | ("step-builder", let arg: I64) => step_builder_idx = arg
      | ("metrics-receiver", let arg: Bool) => is_metrics_receiver = true
      end
    end

    try
      if is_metrics_receiver then
        Receiver(env)
      else
        let sink_builder = sink_builders(step_builder_idx.usize())
        let auth = env.root as AmbientAuth

        let host = addr(0)
        let service = addr(1)

        let target_host = target_addr(0)
        let target_service = target_addr(1)

        let notifier = SinkNodeOutConnectNotify(env)
        let out_conn = TCPConnection(auth, consume notifier,
          target_host, target_service)

        let sink_node_step = sink_builder(out_conn)

        TCPListener(auth, SinkNodeNotifier(env, auth, sink_node_step, host,
          service), host, service)
      end
    else
      env.out.print(
        """
        PARAMETERS:
        -----------------------------------------------------------------------------------
        --run-sink [Runs as sink node]
        --metrics-receiver/-m [Runs as metrics-receiver node]
        --addr <address> [Address sink node is listening on]
        --target-addr <address> [Address sink node sends reports to]
        --step-builder <idx> [Index of sink step builder for this sink node]
        """
      )
    end
