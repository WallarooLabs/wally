trait tag Distributor
  be distribute(cluster_initializer: (ClusterInitializer | None),
    worker_count: USize, worker_names: Array[String] val)

  be topology_ready()
