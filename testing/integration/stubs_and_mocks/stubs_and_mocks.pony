/*

Copyright 2019 The Wallaroo Authors.

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
use "ponytest"
use "wallaroo/core/autoscale"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/partitioning"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/equality"



primitive TestOutputStepGenerator[V: (Hashable & Equatable[V] &
  Stringable val)]
  fun apply(env: Env, auth: AmbientAuth, oc: TestOutputCollector[V]): Step
  =>
    Step(auth, "", RouterRunner(PassthroughPartitionerBuilder),
      _MetricsReporterGenerator(),
      1, _EventLogGenerator(auth), _RecoveryReconnecterGenerator(env, auth),
      recover Map[String, OutgoingBoundary] end, EmptyKeyRegistry,
      DirectRouter(0, oc))

primitive _StepGenerator
  fun apply(env: Env, auth: AmbientAuth): Step =>
    Step(auth, "", _RouterRunnerGenerator(), _MetricsReporterGenerator(),
      1, _EventLogGenerator(auth), _RecoveryReconnecterGenerator(env, auth),
      recover Map[String, OutgoingBoundary] end, EmptyKeyRegistry)

actor EmptyKeyRegistry is KeyRegistry
  be register_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    None
  be unregister_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    None

primitive _MetricsReporterGenerator
  fun apply(): MetricsReporter iso^ =>
    MetricsReporter("", "", _NullMetricsSink)

primitive _EventLogGenerator
  fun apply(auth: AmbientAuth, worker_name: WorkerName = ""): EventLog =>
    EventLog(auth, worker_name, SimpleJournalNoop)

primitive _RecoveryReconnecterGenerator
  fun apply(env: Env, auth: AmbientAuth): RecoveryReconnecter =>
    RecoveryReconnecter(auth, "", "", _DataReceiversGenerator(env, auth),
      _Cluster)

primitive _DataReceiversGenerator
  fun apply(env: Env, auth: AmbientAuth): DataReceivers =>
    DataReceivers(auth, _ConnectionsGenerator(env, auth), "",
      _MetricsReporterGenerator())

primitive _ConnectionsGenerator
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", auth, "", "", "", "",
      _NullMetricsSink, "", "", false, "", false
      where event_log = _EventLogGenerator(auth, "w1"),
      the_journal = SimpleJournalNoop)

//!@
// primitive _RouterRegistryGenerator
//   fun apply(env: Env, auth: AmbientAuth): RouterRegistry =>
//     RouterRegistry(auth, "", _DataReceiversGenerator(env, auth),
//       _ConnectionsGenerator(env, auth),
//       _DummyRecoveryFileCleaner, 0,
//       false, "", _BarrierCoordinatorGenerator(env, auth),
//       _CheckpointInitiatorGenerator(env, auth),
//       _AutoscaleInitiatorGenerator(env, auth))

primitive _BarrierCoordinatorGenerator
  fun apply(env: Env, auth: AmbientAuth): BarrierCoordinator =>
    BarrierCoordinator(auth, "w", _ConnectionsGenerator(env, auth),
      "init")

primitive _AutoscaleInitiatorGenerator
  fun apply(env: Env, auth: AmbientAuth): AutoscaleInitiator =>
    AutoscaleInitiator("w", _BarrierCoordinatorGenerator(env, auth),
      _CheckpointInitiatorGenerator(env, auth))

primitive _CheckpointInitiatorGenerator
  fun apply(env: Env, auth: AmbientAuth): CheckpointInitiator =>
    CheckpointInitiator(auth, "", "", _ConnectionsGenerator(env, auth), 1,
      _EventLogGenerator(auth, "w1"), _BarrierCoordinatorGenerator(env, auth),
      "", SimpleJournalNoop, false)

class _RouterRunnerGenerator
  fun apply(): RouterRunner iso^ =>
    RouterRunner(_EmptyPartitionBuilder)

primitive _EmptyPartitionBuilder is PartitionerBuilder
  fun apply(): Partitioner =>
    _EmptyPartitioner

class _EmptyPartitioner is Partitioner
  fun ref apply[D: Any val](d: D, current_key: Key): Key =>
    current_key

actor _NullMetricsSink
  be send_metrics(metrics: MetricDataList val) =>
    None
  fun ref set_nodelay(state: Bool) =>
    None
  be writev(data: ByteSeqIter) =>
    None
  be dispose() =>
    None

actor _DummyRecoveryFileCleaner is RecoveryFileCleaner
  be clean_shutdown() =>
    None

actor _Cluster is Cluster


//!@
// class iso TestOutputRunner[V: (Hashable & Equatable[V] & Stringable val)]
//   is Runner
//   let _router: TestOutputCollector[V]

//   new iso create(output_collector: TestOutputCollector[V]) =>
//     _router = DirectRouter(0, output_collector)

//   fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
//     data: D, key: Key, event_ts: U64, watermark_ts: U64,
//     producer_id: RoutingId, producer: Producer ref, router: Router,
//     i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
//     metrics_id: U16, worker_ingress_ts: U64,
//     metrics_reporter: MetricsReporter ref): (Bool, U64)
//   =>
//     _output_collector.run[D](metric_name,
//       pipeline_time_spent, data, key, event_ts, watermark_ts, producer_id,
//       producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
//       worker_ingress_ts)
//     (true, 0)

// metric_name: String, pipeline_time_spent: U64, data: D,
//     key: Key, event_ts: U64, watermark_ts: U64, i_producer_id: RoutingId,
//     i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
//     i_seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64

//   fun name(): String => "TestOutputRunner runner"



class val TestBarrierToken is BarrierToken
  let _id: USize

  new val create(id': USize) =>
    _id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let tbt: TestBarrierToken =>
      (_id == tbt._id)
    else
      false
    end

  fun hash(): USize =>
    _id.hash()

  fun id(): USize =>
    _id

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let tbt: TestBarrierToken =>
      _id < tbt._id
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let tbt: TestBarrierToken =>
      _id > tbt._id
    else
      false
    end

  fun string(): String =>
    "TestBarrierToken(" + _id.string() + ")"

// primitive _LocalMapGenerator
//   fun apply(): Map[U128, Step] val =>
//     recover Map[U128, Step] end

// primitive _RoutingIdsGenerator
//   fun apply(): Map[String, U128] val =>
//     recover Map[String, U128] end



// primitive _BoundaryGenerator
//   fun apply(worker_name: String, auth: AmbientAuth): OutgoingBoundary =>
//     OutgoingBoundary(auth, worker_name, "", _MetricsReporterGenerator(),
//       "", "")








// primitive _StatelessPartitionGenerator
//   fun apply(): StatelessPartitionRouter =>
//     LocalStatelessPartitionRouter(0, "", recover Map[U64, RoutingId] end,
//       recover Map[U64, (Step | ProxyRouter)] end, 1)




