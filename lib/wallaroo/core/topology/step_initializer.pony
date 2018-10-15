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
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/grouping"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/ent/barrier"
use "wallaroo/ent/checkpoint"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"


type StepInitializer is (StepBuilder | SourceData | EgressBuilder)

class val StepBuilder
  let _app_name: String
  let _pipeline_name: String
  let _routing_group: (StateName | RoutingId)
  let _runner_builder: RunnerBuilder
  let _id: RoutingId
  let _grouper: (Shuffle | GroupByKey | None)
  let _is_stateful: Bool
  let _parallelism: USize

  new val create(app_name: String,
    pipeline_name': String, r: RunnerBuilder, id': RoutingId,
    routing_group': (StateName | RoutingId),
    grouper: (Shuffle | GroupByKey | None) = None, is_stateful': Bool = false)
  =>
    _app_name = app_name
    _pipeline_name = pipeline_name'
    _runner_builder = r
    _routing_group = routing_group'
    _id = id'
    _grouper = grouper
    _is_stateful = is_stateful'
    _parallelism = r.parallelism()

  fun name(): String => _runner_builder.name()
  fun routing_group(): (StateName | RoutingId | None) => _routing_group
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false
  fun parallelism(): USize => _parallelism

  fun apply(routing_id: RoutingId, worker_name: WorkerName, next: Router,
    metrics_conn: MetricsSink, event_log: EventLog,
    recovery_replayer: RecoveryReconnecter, auth: AmbientAuth,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router_registry: RouterRegistry, router: Router = EmptyRouter): Step tag
  =>
    let runner = _runner_builder(where event_log = event_log, auth = auth,
      router = router, grouper = _grouper)
    let step = Step(auth, consume runner,
      MetricsReporter(_app_name, worker_name, metrics_conn), routing_id,
      event_log, recovery_replayer,
      outgoing_boundaries, router_registry, router)
    step.update_router(next)
    step

class val SourceData
  let _id: RoutingId
  let _pipeline_name: String
  let _name: String
  let _runner_builder: RunnerBuilder
  let _grouper: (Shuffle | GroupByKey | None)
  let _source_listener_builder_builder: SourceListenerBuilderBuilder

  new val create(id': RoutingId, p_name: String, r: RunnerBuilder,
    s: SourceListenerBuilderBuilder,
    grouper: (Shuffle | GroupByKey | None) = None)
  =>
    _id = id'
    _pipeline_name = p_name
    _name = "| " + _pipeline_name + " source | " + r.name() + "|"
    _runner_builder = r
    _grouper = grouper
    _source_listener_builder_builder = s

  fun runner_builder(): RunnerBuilder => _runner_builder

  fun name(): String => _name
  fun routing_group(): (StateName | RoutingId | None) => None
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun parallelism(): USize => 1

  fun source_listener_builder_builder(): SourceListenerBuilderBuilder =>
    _source_listener_builder_builder

class val EgressBuilder
  let _name: String
  let _pipeline_name: String
  let _id: RoutingId
  let _sink_builder: SinkBuilder

  new val create(pipeline_name': String, id': RoutingId,
    sink_builder: SinkBuilder)
  =>
    _pipeline_name = pipeline_name'
    _name = _pipeline_name + " sink"
    _id = id'
    _sink_builder = sink_builder

  fun name(): String => _name
  fun routing_group(): (StateName | RoutingId | None) => None
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun parallelism(): USize => 0

  fun apply(worker_name: String, reporter: MetricsReporter ref,
    event_log: EventLog, recovering: Bool,
    barrier_initiator: BarrierInitiator,
    checkpoint_initiator: CheckpointInitiator, env: Env, auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val =
      recover Map[String, OutgoingBoundary] end): Sink
  =>
    _sink_builder(_name, event_log, reporter.clone(), env, barrier_initiator,
      checkpoint_initiator, recovering)
