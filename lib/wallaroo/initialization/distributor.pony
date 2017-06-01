trait tag Distributor
  be distribute(cluster_initializer: (ClusterInitializer | None),
    worker_count: USize, worker_names: Array[String] val,
    initializer_name: String)

  be topology_ready()
