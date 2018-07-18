/*

Copyright 2017 The Wallaroo Authors.

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
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/snapshot"
use "wallaroo/ent/watermarking"


actor DummyProducer is Producer
  // Producer
  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  fun ref unknown_key(state_name: String, key: Key,
    routing_args: RoutingArguments)
  =>
    None

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    None

  // Muteable
  be mute(c: Consumer) =>
    None

  be unmute(c: Consumer) =>
    None

  // Ackable
  fun ref _acker(): Acker =>
    Acker

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    None

  fun ref flush(low_watermark: SeqId) =>
    None

  // AckRequester
  be request_ack() =>
    None

  // Initializable
  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    None

  be application_created(initializer: LocalTopologyInitializer)
  =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    None

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    None

