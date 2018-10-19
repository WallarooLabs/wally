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
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/checkpoint"


actor DummyProducer is Producer
  // Producer
  fun ref has_route_to(c: Consumer): Bool =>
    false

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    None

  // Muteable
  be mute(c: Consumer) =>
    None

  be unmute(c: Consumer) =>
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

  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    None

  be prepare_for_rollback() =>
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    None

  be register_downstream() =>
    None

  be dispose_with_promise(promise: Promise[None]) =>
    None

  fun ref metrics_reporter(): MetricsReporter =>
    MetricsReporter("", "", _NullMetricsSink)

actor _NullMetricsSink
  be send_metrics(metrics: MetricDataList val) =>
    None

  fun ref set_nodelay(state: Bool) =>
    None

  be writev(data: ByteSeqIter) =>
    None

  be dispose() =>
    None
