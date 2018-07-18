/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


class BarrierStepForwarder
  let _step_id: RoutingId
  let _step: Step ref
  var _barrier_token: BarrierToken = InitialBarrierToken
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()

  // !@ Perhaps we need to add invariant wherever inputs and outputs can be
  // updated in the encapsulating actor to check if barrier is in progress.
  new create(step_id: RoutingId, step: Step ref) =>
    _step_id = step_id
    _step = step

  fun input_blocking(id: RoutingId): Bool =>
    _inputs_blocking.contains(id)

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _barrier_token = barrier_token
    receive_barrier(step_id, producer, barrier_token)

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    @printf[I32]("!@ receive_barrier at Forwarder from %s!\n".cstring(), step_id.string().cstring())
    if barrier_token != _barrier_token then
      @printf[I32]("!@ Received %s when still processing %s\n".cstring(),
        _barrier_token.string().cstring(), barrier_token.string().cstring())
      Fail()
    end

    let inputs = _step.inputs()

    if inputs.contains(step_id) then
      _inputs_blocking(step_id) = producer
      if inputs.size() == _inputs_blocking.size() then
        @printf[I32]("!@ That was last barrier at Forwarder.  FORWARDING!\n".cstring())
        for (o_id, o) in _step.outputs().pairs() do
          match o
          | let ob: OutgoingBoundary =>
            @printf[I32]("!@ FORWARDING TO BOUNDARY\n".cstring())
            ob.forward_barrier(o_id, _step_id,
              _barrier_token)
          else
            @printf[I32]("!@ FORWARDING TO NON BOUNDARY\n".cstring())
            o.receive_barrier(_step_id, _step, _barrier_token)
          end
        end
        _clear()
        _step.barrier_complete(barrier_token)
      end
    else
      Fail()
    end

  fun ref _clear() =>
    _inputs_blocking.clear()
    _barrier_token = InitialBarrierToken
