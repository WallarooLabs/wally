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
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"

type StepInitializer is (StepBuilder | SourceData | EgressBuilder |
  PreStatelessData)

class val StepBuilder
  let _app_name: String
  let _worker_name: String
  let _pipeline_name: String
  let _state_name: String
  let _runner_builder: RunnerBuilder
  let _id: RoutingId
  let _pre_state_target_ids: Array[RoutingId] val
  let _is_stateful: Bool

  new val create(app_name: String, worker_name: String,
    pipeline_name': String, r: RunnerBuilder, id': RoutingId,
    is_stateful': Bool = false,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _pipeline_name = pipeline_name'
    _runner_builder = r
    _state_name = _runner_builder.state_name()
    _id = id'
    _is_stateful = is_stateful'
    _pre_state_target_ids = pre_state_target_ids'

  fun name(): String => _runner_builder.name()
  fun state_name(): String => _state_name
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun pre_state_target_ids(): Array[RoutingId] val => _pre_state_target_ids
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false
  fun clone_router_and_set_input_type(r: Router): Router =>
    _runner_builder.clone_router_and_set_input_type(r)

  fun apply(next: Router, metrics_conn: MetricsSink,
    event_log: EventLog, recovery_replayer: RecoveryReplayer,
    auth: AmbientAuth, outgoing_boundaries: Map[String, OutgoingBoundary] val,
    state_step_creator: StateStepCreator,
    router: Router = EmptyRouter,
    target_id_router: TargetIdRouter = EmptyTargetIdRouter): Step tag
  =>
    let runner = _runner_builder(where event_log = event_log, auth = auth,
      router = router, pre_state_target_ids' = pre_state_target_ids())
    let step = Step(auth, consume runner,
      MetricsReporter(_app_name, _worker_name, metrics_conn), _id,
      event_log, recovery_replayer,
      outgoing_boundaries, state_step_creator, router, target_id_router)
    step.update_router(next)
    step

class val SourceData
  let _id: RoutingId
  let _pipeline_name: String
  let _name: String
  let _state_name: String
  let _builder: SourceBuilderBuilder
  let _runner_builder: RunnerBuilder
  let _source_listener_builder_builder: SourceListenerBuilderBuilder
  let _pre_state_target_ids: Array[RoutingId] val

  new val create(id': RoutingId, b: SourceBuilderBuilder, r: RunnerBuilder,
    s: SourceListenerBuilderBuilder,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end)
  =>
    _id = id'
    _pipeline_name = b.name()
    _name = "| " + _pipeline_name + " source | " + r.name() + "|"
    _builder = b
    _runner_builder = r
    _state_name = _runner_builder.state_name()
    _source_listener_builder_builder = s

    _pre_state_target_ids = pre_state_target_ids'

  fun builder(): SourceBuilderBuilder => _builder
  fun runner_builder(): RunnerBuilder => _runner_builder

  fun name(): String => _name
  fun state_name(): String => _state_name
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun pre_state_target_ids(): Array[RoutingId] val => _pre_state_target_ids
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    _runner_builder.clone_router_and_set_input_type(r)

  fun source_listener_builder_builder(): SourceListenerBuilderBuilder =>
    _source_listener_builder_builder


class val EgressBuilder
  let _name: String
  let _pipeline_name: String
  let _id: RoutingId
  // None if this is a sink to an external system
  let _proxy_addr: (ProxyAddress | None)
  let _sink_builder: (SinkBuilder | None)

  new val create(pipeline_name': String, id': RoutingId,
    sink_builder: (SinkBuilder | None) = None,
    proxy_addr: (ProxyAddress | None) = None)
  =>
    _pipeline_name = pipeline_name'
    _name =
      match proxy_addr
      | let pa: ProxyAddress =>
        "Proxy to " + pa.worker
      else
        _pipeline_name + " sink"
      end

    _id = id'
    _proxy_addr = proxy_addr
    _sink_builder = sink_builder

  fun name(): String => _name
  fun state_name(): String => ""
  fun pipeline_name(): String => _pipeline_name
  fun id(): RoutingId => _id
  fun pre_state_target_ids(): Array[RoutingId] val => recover Array[RoutingId] end
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun clone_router_and_set_input_type(r: Router,
    dr: (Router | None) = None): Router => r

  fun target_address(): (ProxyAddress | KeyDistribution | None) =>
    _proxy_addr

  fun apply(worker_name: String, reporter: MetricsReporter ref,
    event_log: EventLog, recovering: Bool,
    barrier_initiator: BarrierInitiator,
    snapshot_initiator: SnapshotInitiator, env: Env, auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val =
      recover Map[String, OutgoingBoundary] end): Consumer ?
  =>
    match _proxy_addr
    | let p: ProxyAddress =>
      try
        proxies(p.worker)?
      else
        @printf[I32](("Couldn't find proxy for " + p.worker + ".\n").cstring())
        error
      end
    | None =>
      match _sink_builder
      | let sb: SinkBuilder =>
        sb(_name, event_log, reporter.clone(), env, barrier_initiator,
          snapshot_initiator, recovering)
      else
        EmptySink
      end
    end

class val PreStateData
  let _state_name: String
  let _pre_state_name: String
  let _runner_builder: RunnerBuilder
  let _target_ids: Array[RoutingId] val

  new val create(runner_builder: RunnerBuilder, t_ids: Array[RoutingId] val) =>
    _runner_builder = runner_builder
    _state_name = runner_builder.state_name()
    _pre_state_name = runner_builder.name()
    _target_ids = t_ids

  fun state_name(): String => _state_name
  fun pre_state_name(): String => _pre_state_name
  fun target_ids(): Array[RoutingId] val => _target_ids
  fun clone_router_and_set_input_type(r: Router): Router =>
    _runner_builder.clone_router_and_set_input_type(r)

class val PreStatelessData
  """
  Unlike PreStateData, this is simply used to create a StatelessPartitionRouter
  during local initialization. Whatever step/s come before a stateless
  partition do not need to do anything special; they only need the correct
  StatelessPartitionRouter.

  This is a StepInitializer because it inhabits a node in the local topology
  graph, but it does not provide the blueprint for a step.  Instead, it
  provides a blueprint for creating the router for the previous step/s in the
  graph that have edges into it.
  """
  let _pipeline_name: String
  let _id: U128
  let partition_idx_to_worker: Map[SeqPartitionIndex, String] val
  let partition_idx_to_step_id: Map[SeqPartitionIndex, RoutingId] val
  let worker_to_step_id: Map[String, Array[RoutingId] val] val
  let steps_per_worker: USize

  new val create(pipeline_name': String, step_id': RoutingId,
    partition_idx_to_worker': Map[SeqPartitionIndex, String] val,
    partition_idx_to_step_id': Map[SeqPartitionIndex, RoutingId] val,
    worker_to_step_id': Map[String, Array[RoutingId] val] val,
    steps_per_worker': USize)
  =>
    _pipeline_name = pipeline_name'
    _id = step_id'
    partition_idx_to_worker = partition_idx_to_worker'
    partition_idx_to_step_id = partition_idx_to_step_id'
    worker_to_step_id = worker_to_step_id'
    steps_per_worker = steps_per_worker'

  fun name(): String => "PreStatelessData"
  fun state_name(): String => ""
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_ids(): Array[RoutingId] val => recover Array[RoutingId] end
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun clone_router_and_set_input_type(r: Router,
    dr: (Router | None) = None): Router => r
