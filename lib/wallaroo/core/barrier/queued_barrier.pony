/*

Copyright 2018 The Wallaroo Authors.

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

use "wallaroo/core/common"
use "wallaroo/core/topology"


trait BarrierProcessor
  fun ref process_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)

class val QueuedBarrier
  let _input_id: RoutingId
  let _producer: Producer
  let _barrier_token: BarrierToken

  new val create(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _input_id = input_id
    _producer = producer
    _barrier_token = barrier_token

  fun inject_barrier(b_processor: BarrierProcessor ref) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("Injecting queued barrier %s\n".cstring(),
        _barrier_token.string().cstring())
    end
    b_processor.process_barrier(_input_id, _producer, _barrier_token)
