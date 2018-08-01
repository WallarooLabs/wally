/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/common"
use "wallaroo/core/sink"
use "wallaroo_labs/mort"


class BarrierSinkAcker
  let _step_id: RoutingId
  let _sink: Sink ref
  var _barrier_token: BarrierToken = InitialBarrierToken
  let _barrier_initiator: BarrierInitiator
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()

  // !@ Perhaps to add invariant wherever inputs can be updated in
  // the encapsulating actor to check if barrier is in progress.
  new create(step_id: RoutingId, sink: Sink ref,
    barrier_initiator: BarrierInitiator)
  =>
    _step_id = step_id
    _sink = sink
    _barrier_initiator = barrier_initiator

  fun ref higher_priority(token: BarrierToken): Bool =>
    token > _barrier_token

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
    if barrier_token != _barrier_token then
      @printf[I32]("SinkAcker: Expected %s, got %s\n".cstring(), _barrier_token.string().cstring(), barrier_token.string().cstring())
      Fail()
    end

    let inputs = _sink.inputs()
    if inputs.contains(step_id) then
      _inputs_blocking(step_id) = producer
      _check_completion(inputs)
    else
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
    _check_completion(_sink.inputs())

  fun ref _check_completion(inputs: Map[RoutingId, Producer] box) =>
    // @printf[I32]("!@ receive_barrier at TCPSink: %s inputs, %s received\n".cstring(), inputs.size().string().cstring(), _inputs_blocking.size().string().cstring())
    if inputs.size() == _inputs_blocking.size() then
      _barrier_initiator.ack_barrier(_sink, _barrier_token)
      _sink.barrier_complete(_barrier_token)
      clear()
    end

  fun ref clear() =>
    _inputs_blocking.clear()
    _barrier_token = InitialBarrierToken
