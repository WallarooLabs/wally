primitive StartupHelp
  fun apply(env: Env) =>
    platform(env)
    sink_node(env)

  fun sink_node(env: Env) =>
    _sink_node(env)
    metrics_receiver(env)

  fun platform(env: Env) =>
    env.out.print(
      """
      To run as platform:
      -----------------------------------------------------------------------------------
      --leader/-l [Sets process as leader]
      --worker-count/-w <count> [Tells the leader how many workers to wait for]
      --name/-n <node_name> [Sets the name for the process in the Buffy cluster]
      --phone-home/-p <address> [Sets the address for phone home]
      --leader-control-address/-c <address> [Sets the address for the leader's control
                                          channel address]
      --leader-data-address/-d <address> [Sets the address for the leader's data channel
                                       address]
      --source/-r <comma-delimited source_addresses> [Sets the addresses for the sink]
      --sink/-k <comma-delimited sink_addresses> [Sets the addresses for the sink]
      --metrics/-m <metrics-receiver address> [Sets the address for the metrics receiver]
      --spike-seed <seed> [Optionally sets seed for spike]
      --spike-delay [Set flag for spike delay]
      --spike-drop [Set flag for spike drop]
      -----------------------------------------------------------------------------------
      """
    )

  fun metrics_receiver(env: Env) =>
    env.out.print(
      """
      To run as Metrics Receiver:
      -----------------------------------------------------------------------------------
      --run-sink [Runs as sink node (required for metrics-receiver)]
      --metrics-receiver/-r [Runs as metrics-receiver node]
      --listen [Listen address in xxx.xxx.xxx.xxx:pppp format]
      --monitor [Monitoring Hub address in xxx.xxx.xxx.xxx:pppp format]
      --app-name [Application name to report to Monitoring Hub]
      --period [Aggregation periods for reports to Monitoring Hub]
      --delay [Maximum period of time before sending data]
      --report-file/rf [File path to write reports to]
      --report-period/rp [Aggregation period for reports in report-file]
      --phone-home [Address external coordinator is listening on]
      --name [Name to use with external coordinator]
      -----------------------------------------------------------------------------------
      """
    )

  fun _sink_node(env: Env) =>
    env.out.print(
      """
      To run as generic Sink Node:
      -----------------------------------------------------------------------------------
      --run-sink [Runs as sink node]
      --listen/-l <address> [Address sink node is listening on]
      --target-addr/-t <address> [Address sink node sends reports to]
      --step-builder <idx> [Index of sink step builder for this sink node]
      --phone-home/-p [Address external coordinator is listening on]
      --name/-n <name> [Name of sink node]
      -----------------------------------------------------------------------------------
      """
    )