/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/common"
use "wallaroo/core/registries"

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

  be stop_the_world(exclusions: Array[String] val) =>
    None

  be request_cluster_unmute() =>
    None

  be inform_contacted_worker_of_join(contacted_worker: String) =>
    None

  be inform_worker_of_boundary_count(target_worker: String, count: USize) =>
    None

  be worker_completed_migration_batch(ack_target: String) =>
    None
