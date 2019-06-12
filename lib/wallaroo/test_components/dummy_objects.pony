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
use "wallaroo/core/registries"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/state"
use "wallaroo/core/step"
use "wallaroo/core/topology"
use "wallaroo_labs/equality"


actor EmptyKeyRegistry is KeyRegistry
  be register_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    None

  be unregister_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    None

primitive _MetricsReporterDummyBuilder
  fun apply(): MetricsReporter iso^ =>
    MetricsReporter("", "", _NullMetricsSink)

primitive _EventLogDummyBuilder
  fun apply(auth: AmbientAuth, worker_name: WorkerName = ""): EventLog =>
    EventLog(auth, worker_name, SimpleJournalNoop)

primitive _RecoveryReconnecterDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): RecoveryReconnecter =>
    RecoveryReconnecter(auth, "", "", _DataReceiversDummyBuilder(env, auth),
      _Cluster)

primitive _DataReceiversDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): DataReceivers =>
    DataReceivers(auth, _ConnectionsDummyBuilder(env, auth), "",
      _MetricsReporterDummyBuilder())

primitive _ConnectionsDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", auth, "", "", "", "",
      _NullMetricsSink, "", "", false, "", false
      where event_log = _EventLogDummyBuilder(auth, "w1"),
      the_journal = SimpleJournalNoop)

primitive _BarrierCoordinatorDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): BarrierCoordinator =>
    BarrierCoordinator(auth, "w", _ConnectionsDummyBuilder(env, auth),
      "init")

primitive _AutoscaleBarrierInitiatorDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): AutoscaleBarrierInitiator =>
    AutoscaleBarrierInitiator("w", _BarrierCoordinatorDummyBuilder(env, auth),
      _CheckpointInitiatorDummyBuilder(env, auth))

primitive _CheckpointInitiatorDummyBuilder
  fun apply(env: Env, auth: AmbientAuth): CheckpointInitiator =>
    CheckpointInitiator(auth, "", "", _ConnectionsDummyBuilder(env, auth), 1,
      _EventLogDummyBuilder(auth, "w1"), _BarrierCoordinatorDummyBuilder(env, auth),
      "", SimpleJournalNoop, false)

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
