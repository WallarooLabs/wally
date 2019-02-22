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
use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/recovery"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

trait tag Sink is (Consumer & DisposableActor & BarrierProcessor)
  be barrier_fully_acked(token: BarrierToken)
  fun inputs(): Map[RoutingId, Producer] box

interface val SinkConfig[Out: Any val]
  fun apply(): SinkBuilder

interface val SinkBuilder
  fun apply(sink_name: String, event_log: EventLog,
    reporter: MetricsReporter iso, env: Env,
    barrier_initiator: BarrierInitiator,
    checkpoint_initiator: CheckpointInitiator, recovering: Bool): Sink
