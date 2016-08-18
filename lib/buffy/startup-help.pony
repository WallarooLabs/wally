primitive StartupHelp
  fun apply(env: Env) =>
    platform(env)

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
      --metrics-period <period> [Sets the aggregation period for metrics, in seconds]
      --metrics-file <file path> [Sets the filepath for metrics report file]
      --metrics-file-period <period> [Sets the aggregatin period for metrics report file, in seconds]
      --app-name <name> [Monitoring hub app name]
      --spike-seed <seed> [Optionally sets seed for spike]
      --spike-delay [Set flag for spike delay]
      --spike-drop [Set flag for spike drop]
      -----------------------------------------------------------------------------------
      """
    )
