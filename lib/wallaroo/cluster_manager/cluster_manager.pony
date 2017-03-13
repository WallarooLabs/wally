interface tag ClusterManager
  """
  ClusterManager

  Interface for interacting with an external cluster manager to request a
  new Wallaroo worker.
  """
  be request_new_worker()

interface tag NewWorkerRequester
  """
  NewWorkerRequester

  Interface for actors that can request a new Wallaroo worker from a
  ClusterManager.
  """
  be request_new_worker()
