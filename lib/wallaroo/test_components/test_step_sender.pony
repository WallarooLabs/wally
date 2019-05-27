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
use "wallaroo/core/barrier"
use "wallaroo/core/common"
use "wallaroo/core/step"
use "wallaroo/core/topology"

primitive TestStepSender[V: (Hashable & Equatable[V] val)]
  fun send_seq(step: Step, inputs: Array[V] val, producer_id: RoutingId,
    producer: Producer)
  =>
    for input in inputs.values() do
      send(step, input, producer_id, producer)
    end

  fun send(step: Step, input: V, producer_id: RoutingId, producer: Producer) =>
    step.run[V]("", 1, input, "", 1, 1, producer_id, producer, 1, None, 1, 1,
      1, 1)

  fun send_barrier(step: Step, token: BarrierToken, producer_id: RoutingId,
    producer: Producer)
  =>
    step.receive_barrier(producer_id, producer, token)
