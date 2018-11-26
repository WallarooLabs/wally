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
use "promises"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/checkpoint"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"


interface val SourceConfig
  fun default_partitioner_builder(): PartitionerBuilder
  fun source_listener_builder_builder(): SourceListenerBuilderBuilder

interface val TypedSourceConfig[In: Any val] is SourceConfig

class val SourceConfigWrapper
  let _name: String
  let _source_config: SourceConfig

  new val create(n: String, sc: SourceConfig) =>
    _name = n
    _source_config = sc

  fun name(): String => _name
  fun source_config(): SourceConfig => _source_config

trait tag Source is (Producer & DisposableActor & BoundaryUpdatable &
  StatusReporter)
  // TODO: Rename register_downstreams
  be register_downstreams(promise: Promise[Source])
  be update_router(router: StatePartitionRouter)
  be remove_route_to_consumer(id: RoutingId, c: Consumer)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  be reconnect_boundary(target_worker_name: WorkerName)
  be disconnect_boundary(worker: WorkerName)
  be mute(a: Any tag)
  be unmute(a: Any tag)
  be initiate_barrier(token: BarrierToken)
  be barrier_complete(token: BarrierToken)
  be update_worker_data_service(worker_name: String,
    host: String, service: String)
  // Called to indicate that an in progress checkpoint when Source was created
  // is complete.
  // TODO: We can probably remove this with some improvements to our
  // initialization order of events.
  be first_checkpoint_complete()

trait tag SourceListener is (DisposableActor & BoundaryUpdatable)
  be recovery_protocol_complete()
  be update_router(router: StatePartitionRouter)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  be update_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
