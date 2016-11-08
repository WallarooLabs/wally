primitive StartupHelp
  fun apply(env: Env) =>
    env.out.print(
      """
      To run Wallaroo:
      -----------------------------------------------------------------------------------
      --in/-i *[Comma-separated list of input addresses sources listen on]
      --out/-o *[Sets address for sink outputs]
      --control/-c *[Sets address for control channel]
      --data/-d *[Sets address for data channel]
      --phone-home/-p [Sets address for phone home connection]
      --worker-count/-w *[Sets total number of workers, including topology
        initializer]
      --worker-name/-n *[Sets name for this worker]

      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --topology-initializer/-t [Sets this process as the topology 
        initializing process (that status is meaningless after init is done)]
      -----------------------------------------------------------------------------------
      """
    )
