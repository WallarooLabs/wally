/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/common"
use "wallaroo/ent/router_registry"

// TODO: Figure out if there's a compilation order making Fail() appear like
// it hasn't been declared and then replace None with Fail() in these defaults
trait tag Cluster
  """
  A trait for sending messages to workers in the cluster.
  """
  be send_control(worker: String, data: Array[ByteSeq] val) =>
    None

  be send_control_to_cluster(data: Array[ByteSeq] val) =>
    None

  be send_control_to_cluster_with_exclusions(data: Array[ByteSeq] val,
    exclusions: Array[String] val)
  =>
    None

  be send_data(worker: String, data: Array[ByteSeq] val) =>
    None

  be send_data_to_cluster(data: Array[ByteSeq] val) =>
    None

    //!@
  // be notify_cluster_of_new_key(key: Key,
  //   state_name: String, exclusions: Array[String] val =
  //   recover Array[String] end)

  be stop_the_world(exclusions: Array[String] val) =>
    None

  be request_cluster_unmute() =>
    None

  be inform_contacted_worker_of_join(contacted_worker: String) =>
    None

  be inform_worker_of_boundary_count(target_worker: String, count: USize) =>
    None

  be ack_migration_batch_complete(ack_target: String) =>
    None
