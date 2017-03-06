interface tag ClusterManager
  """
  ClusterManager

  Interface for interacting with an external cluster manager to request a
  new Wallaroo worker.
  """
  be request_new_worker()
