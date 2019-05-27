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
use "net"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/partitioning"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/step"


type ExecutionStageBuilder is (StepBuilder | SourceData | EgressBuilder |
  MultiSinkBuilder)

class val StepBuilder
  let _app_name: String
  let _routing_group: (RoutingId)
  let _runner_builder: RunnerBuilder
  let _id: RoutingId
  let _partitioner_builder: PartitionerBuilder
  let _is_stateful: Bool
  let _parallelism: USize

  new val create(app_name: String, r: RunnerBuilder, id': RoutingId,
    routing_group': RoutingId,
    partitioner_builder': PartitionerBuilder = SinglePartitionerBuilder, is_stateful': Bool = false)
  =>
    _app_name = app_name
    _runner_builder = r
    _routing_group = routing_group'
    _id = id'
    _partitioner_builder = partitioner_builder'
    _is_stateful = is_stateful'
    _parallelism = r.parallelism()

  fun name(): String => _runner_builder.name()
  fun routing_group(): RoutingId => _routing_group
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false
  fun partitioner_builder(): PartitionerBuilder => _partitioner_builder
  fun parallelism(): USize => _parallelism
  fun local_routing(): Bool => _runner_builder.local_routing()

  fun apply(routing_id: RoutingId, worker_name: WorkerName, next: Router,
    metrics_conn: MetricsSink, event_log: EventLog,
    recovery_replayer: RecoveryReconnecter, auth: AmbientAuth,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router_registry: RouterRegistry, is_recovering: Bool,
    router: Router = EmptyRouter): Step tag
  =>
    let runner = _runner_builder(where event_log = event_log, auth = auth,
      router = router, partitioner_builder = _partitioner_builder)
    let step = Step(auth, worker_name, consume runner,
      MetricsReporter(_app_name, worker_name, metrics_conn), routing_id,
      event_log, recovery_replayer,
      outgoing_boundaries, router_registry
      where router' = router, is_recovering = is_recovering)
    step.update_router(next)
    step

class val SourceData
  let _id: RoutingId
  let _name: String
  let _comp_name: String
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
  let _source_coordinator_builder_builder: SourceCoordinatorBuilderBuilder

  new val create(id': RoutingId, name': String, r: RunnerBuilder,
    s: SourceCoordinatorBuilderBuilder, partitioner_builder': PartitionerBuilder)
  =>
    _id = id'
    _name = name'
    _comp_name = "| " + _name + " source | " + r.name() + "|"
    _runner_builder = r
    _partitioner_builder = partitioner_builder'
    _source_coordinator_builder_builder = s

  fun runner_builder(): RunnerBuilder => _runner_builder

  fun name(): String => _name
  fun computations_name(): String => _comp_name
  fun routing_group(): (RoutingId | None) => None
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun partitioner_builder(): PartitionerBuilder => _partitioner_builder
  fun parallelism(): USize => 1

  fun source_coordinator_builder_builder(): SourceCoordinatorBuilderBuilder =>
    _source_coordinator_builder_builder

class val EgressBuilder
  let _name: String
  let _id: RoutingId
  let _sink_builder: SinkBuilder

  new val create(app_name: String, id': RoutingId, sink_builder: SinkBuilder)
  =>
    _name = app_name + " sink"
    _id = id'
    _sink_builder = sink_builder

  fun name(): String => _name
  fun routing_group(): (RoutingId | None) => None
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun partitioner_builder(): PartitionerBuilder => SinglePartitionerBuilder
  fun parallelism(): USize => 0

  fun apply(worker_name: String, reporter: MetricsReporter ref,
    event_log: EventLog, recovering: Bool,
    barrier_coordinator: BarrierCoordinator,
    checkpoint_initiator: CheckpointInitiator, env: Env, auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val =
      recover Map[String, OutgoingBoundary] end): Sink
  =>
    _sink_builder(_name, event_log, reporter.clone(), env, barrier_coordinator,
      checkpoint_initiator, recovering, worker_name, auth)

class val MultiSinkBuilder
  let _name: String
  let _id: RoutingId
  let _sink_builders: Array[SinkBuilder] val

  new val create(app_name: String, id': RoutingId,
    sink_builders: Array[SinkBuilder] val)
  =>
    _name = app_name + " sinks"
    _id = id'
    _sink_builders = sink_builders

  fun name(): String => _name
  fun routing_group(): (RoutingId | None) => None
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun partitioner_builder(): PartitionerBuilder => SinglePartitionerBuilder
  fun parallelism(): USize => _sink_builders.size()

  fun apply(worker_name: String, reporter: MetricsReporter ref,
    event_log: EventLog, recovering: Bool,
    barrier_coordinator: BarrierCoordinator,
    checkpoint_initiator: CheckpointInitiator, env: Env, auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val =
      recover Map[String, OutgoingBoundary] end): Array[Sink] val
  =>
    let sinks = recover iso Array[Sink] end
    for sb in _sink_builders.values() do
      let next_sink = sb(_name, event_log, reporter.clone(), env,
        barrier_coordinator, checkpoint_initiator, recovering,
        worker_name, auth)
      sinks.push(next_sink)
    end
    consume sinks
