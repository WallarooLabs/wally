/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

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
