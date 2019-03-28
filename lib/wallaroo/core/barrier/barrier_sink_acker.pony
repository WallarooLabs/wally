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

use "collections"
use "wallaroo/core/common"
use "wallaroo/core/sink"
use "wallaroo_labs/mort"


class BarrierSinkAcker
  let _sink_id: RoutingId
  let _sink: Sink ref
  var _barrier_token: BarrierToken = InitialBarrierToken
  let _barrier_coordinator: BarrierCoordinator
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()
  var _force_queue: Bool = false

  new create(sink_id: RoutingId, sink: Sink ref,
    barrier_coordinator: BarrierCoordinator)
  =>
    _sink_id = sink_id
    _sink = sink
    _barrier_coordinator = barrier_coordinator

  fun ref higher_priority(token: BarrierToken): Bool =>
    token > _barrier_token

  fun ref lower_priority(token: BarrierToken): Bool =>
    token < _barrier_token

  fun input_blocking(id: RoutingId): Bool =>
    if _force_queue then
      return true
    end
    _inputs_blocking.contains(id)

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _barrier_token = barrier_token
    receive_barrier(step_id, producer, barrier_token, true)

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken, ack_barrier_if_complete: Bool)
  =>
    if barrier_token != _barrier_token then
      @printf[I32]("SinkAcker: Expected %s, got %s\n".cstring(), _barrier_token.string().cstring(), barrier_token.string().cstring())
      Fail()
    end

    let inputs = _sink.inputs()
    if inputs.contains(step_id) then
      _inputs_blocking(step_id) = producer
      _check_completion(inputs, ack_barrier_if_complete)
    else
      @printf[I32]("Failed to find step_id %s in inputs at Sink %s\n".cstring(), step_id.string().cstring(), _sink_id.string().cstring())
      Fail()
    end

  fun ref remove_input(input_id: RoutingId) =>
    """
    Called if an input leaves the system during barrier processing. This should
    only be possible with Sources that are closed (e.g. when a TCPSource
    connection is dropped).
    """
    if _inputs_blocking.contains(input_id) then
      try
        _inputs_blocking.remove(input_id)?
      else
        Unreachable()
      end
    end
    _check_completion(_sink.inputs(), true)

  fun ref _check_completion(inputs: Map[RoutingId, Producer] box,
    ack_barrier_if_complete: Bool)
   =>
    if inputs.size() == _inputs_blocking.size() then
      if ack_barrier_if_complete then
        _barrier_coordinator.ack_barrier(_sink, _barrier_token)
      else
        // The sink has told us that it is responsible for calling
        // _barrier_coordinator.ack_barrier()
        None
      end
      let b_token = _barrier_token
      clear()
      _sink.barrier_complete(b_token)
    end

  fun ref clear() =>
    _inputs_blocking.clear()
    _barrier_token = InitialBarrierToken
    _force_queue = false

  fun ref set_force_queue() =>
    _force_queue = true
