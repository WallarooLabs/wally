primitive StartupHelp
  fun apply(env: Env) =>
    @printf[I32](
      """
      To run Wallaroo:
      -----------------------------------------------------------------------------------
      --in/-i *[Comma-separated list of input addresses sources listen on]
      --control/-c *[Sets address for initializer control channel]
      --data/-d *[Sets address for initializer data channel]
      --my-control [Optionally sets address for my control channel]
      --my-data [Optionally sets address for my data channel]
      --phone-home/-p [Sets address for phone home connection]
      --external/-e [Sets address for external message channel]
      --worker-count/-w *[Sets total number of workers, including topology
        initializer]
      --name/-n *[Sets name for this worker]

      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --cluster-initializer/-t [Sets this process as the topology
        initializing process (that status is meaningless after init is done)]
      --resilience-dir/-r [Sets directory to write resilience files to,
        e.g. -r /tmp/data (no trailing slash)]
      --event_log-file-length/-l [Optionally sets initial file length for event_log
        backend file]

      --join/-j [When a new worker is joining a running cluster, pass the
        control channel address of any worker as the value for this parameter]
      --stop-world/-u [Sets pause before state migration after stop the world]
      -----------------------------------------------------------------------------------
      """.cstring()
    )
