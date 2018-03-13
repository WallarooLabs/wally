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
use "wallaroo/core/invariant"
use "wallaroo_labs/mort"

trait CustomAction
  fun ref apply()

actor InitialFinishedAckRequester is FinishedAckRequester
  """
  Used when we are the initiator of a chain of finished ack requests
  """
  let _step_id: StepId

  new create(step_id: StepId) =>
    _step_id = step_id

  be receive_finished_ack(request_id: RequestId) =>
    ifdef debug then
      // !@TODO: Remove "This step id"
      @printf[I32](("Received finished ack at InitialFinishedAckRequester. " +
        "This indicates the originator of a chain of finished ack requests " +
        "has received the final ack. Request id received: %s. This step id: %s\n").cstring(),
        request_id.string().cstring(), _step_id.string().cstring())
    end
    None

  be try_finish_request_early(requester_id: StepId) =>
    None

actor EmptyFinishedAckRequester is FinishedAckRequester
  be receive_finished_ack(request_id: RequestId) =>
    None

  be try_finish_request_early(requester_id: StepId) =>
    None

class FinishedAckWaiter
  // This will be 0 for data receivers, router registry, and boundaries
  let _step_id: StepId
  let _id_gen: RequestIdGenerator = _id_gen.create()
  // Map from the requester_id to the request id it sent us
  let _upstream_request_ids: Map[StepId, RequestId] =
    _upstream_request_ids.create()
  // Map from request_ids we generated to the requester_id for the
  // original upstream request they're related to
  let _downstream_request_ids: Map[RequestId, StepId] =
    _downstream_request_ids.create()
  let _pending_acks: Map[StepId, SetIs[RequestId]] = _pending_acks.create()
  let _upstream_requesters: Map[StepId, FinishedAckRequester] =
    _upstream_requesters.create()
  let _custom_actions: Map[StepId, CustomAction] = _custom_actions.create()

  new create(id: StepId = 0) =>
    _step_id = id

  fun ref initiate_request(initiator_id: StepId,
    custom_action: (CustomAction | None) = None)
  =>
    add_new_request(initiator_id, 0, InitialFinishedAckRequester(_step_id))
    match custom_action
    | let ca: CustomAction =>
      set_custom_action(initiator_id, ca)
    end

  fun ref add_new_request(requester_id: StepId, request_id: RequestId,
    upstream_requester': (FinishedAckRequester | None) = None,
    custom_action: (CustomAction | None) = None)
  =>
    let upstream_requester =
      match upstream_requester'
      | let far: FinishedAckRequester => far
      else
        EmptyFinishedAckRequester
      end

    // If _upstream_request_ids contains the requester_id, then we're
    // already processing a request from it.
    if not _upstream_request_ids.contains(requester_id) then
      _upstream_request_ids(requester_id) = request_id
      _upstream_requesters(requester_id) = upstream_requester
      _pending_acks(requester_id) = SetIs[RequestId]
      match custom_action
      | let ca: CustomAction =>
        set_custom_action(requester_id, ca)
      end
    else
      ifdef debug then
        @printf[I32]("Already processing a request from %s. Ignoring.\n"
          .cstring(), requester_id.string().cstring())
      end
      //!@
      upstream_requester.receive_finished_ack(request_id)
    end

  fun ref set_custom_action(requester_id: StepId, custom_action: CustomAction)
  =>
    _custom_actions(requester_id) = custom_action

  fun ref run_custom_action(requester_id: StepId) =>
    try
      _custom_actions(requester_id)?()
    else
      Fail()
    end

  fun ref add_consumer_request(requester_id: StepId,
    supplied_id: (RequestId | None) = None): RequestId
  =>
    let request_id =
      match supplied_id
      | let r_id: RequestId => r_id
      else
        _id_gen()
      end
    try
      _downstream_request_ids(request_id) = requester_id
      _pending_acks(requester_id)?.set(request_id)
    else
      Fail()
    end
    request_id

  fun already_added_request(requester_id: StepId): Bool =>
    _upstream_request_ids.contains(requester_id)

  // !@
  fun pending_request(): Bool =>
    _upstream_request_ids.size() > 0

  fun ref unmark_consumer_request(request_id: RequestId) =>
    try
      // @printf[I32]("!@ unmark_consumer_request 1\n".cstring())
      let requester_id = _downstream_request_ids(request_id)?
      // @printf[I32]("!@ received ack for request_id %s (associated with requester %s). (reported from %s)\n".cstring(), request_id.string().cstring(), requester_id.string().cstring(), _step_id.string().cstring())
      // @printf[I32]("!@ unmark_consumer_request 2\n".cstring())
      let id_set = _pending_acks(requester_id)?
      ifdef debug then
        Invariant(id_set.contains(request_id))
      end
      id_set.unset(request_id)
      // @printf[I32]("!@ unmark_consumer_request 3\n".cstring())
      _downstream_request_ids.remove(request_id)?
      // @printf[I32]("!@ unmark_consumer_request COMPLETE\n".cstring())
      _check_send_run(requester_id)
    else
      @printf[I32]("!@ About to fail on %s\n".cstring(), _step_id.string().cstring())
      Fail()
    end

  fun ref try_finish_request_early(requester_id: StepId) =>
    // @printf[I32]("!@ try_finish_request_early\n".cstring())
    _check_send_run(requester_id)

  fun ref clear() =>
    // @printf[I32]("!@ finished_ack CLEAR on %s\n".cstring(), _step_id.string().cstring())
    _pending_acks.clear()
    _downstream_request_ids.clear()
    _upstream_request_ids.clear()
    _upstream_requesters.clear()
    _custom_actions.clear()

  //!@
  fun report_status(code: ReportStatusCode) =>
    match code
    | FinishedAcksStatus =>
      var pending: USize = 0
      var requester_id: StepId = 0
      for (r_id, pa) in _pending_acks.pairs() do
        if pa.size() > 0 then
          requester_id = r_id
          pending = pending + 1
        end
      end
      // @printf[I32]("!@ waiting at %s on %s pending ack groups, for requester ids:\n".cstring(), _step_id.string().cstring(), pending.string().cstring())
      // if pending == 1 then
        // @printf[I32]("!@ %s waiting for one for requester id %s\n".cstring(), _step_id.string().cstring(), requester_id.string().cstring())
      // end
      // for p in _pending_acks.keys() do
      //   @printf[I32]("!@ %s (from %s)\n".cstring(), p.string().cstring(), _step_id.string().cstring())
      // end
    end

  fun ref _check_send_run(requester_id: StepId) =>
    try
      // @printf[I32]("!@ _pending_acks size: %s for requester_id %s (reported from %s). Listing pending acks:\n".cstring(), _pending_acks(requester_id)?.size().string().cstring(), requester_id.string().cstring(), _step_id.string().cstring())
      // for pending_ack in _pending_acks(requester_id)?.values() do
      //   @printf[I32]("!@ -- %s\n".cstring(), pending_ack.string().cstring())
      // end
      if _pending_acks(requester_id)?.size() == 0 then
        let upstream_request_id = _upstream_request_ids(requester_id)?
        _upstream_requesters(requester_id)?
          .receive_finished_ack(upstream_request_id)
        if _custom_actions.contains(requester_id) then
          _custom_actions(requester_id)?()
          _custom_actions.remove(requester_id)?
        end

        //!@
        // // Clean up
        // _pending_acks.remove(requester_id)?
        // _upstream_request_ids.remove(requester_id)?
        // _upstream_requesters.remove(requester_id)?

      end
    else
      Fail()
    end

    //!@
    // @printf[I32]("!@ --awaiting after: %s\n".cstring(),
    //   _awaiting_finished_ack_from.size().string().cstring())
    // if should_send_upstream() then
    //   @printf[I32]("!@ should_send_upstream\n".cstring())
    //   _upstream_requester.receive_finished_ack(upstream_request_id)
    // //!@
    // else
    //   @printf[I32]("!@ not should_send_upstream\n".cstring())
    // end


    //!@
  // fun should_send_upstream(): Bool =>
  //   _awaiting_finished_ack_from.size() == 0

  // fun ref unmark_consumer_request(request_id: RequestId): Bool =>
  //   @printf[I32]("!@ --awaiting before: %s\n".cstring(),
  //     _awaiting_finished_ack_from.size().string().cstring())
  //   _awaiting_finished_ack_from.unset(request_id)
  //   @printf[I32]("!@ --awaiting after: %s\n".cstring(),
  //     _awaiting_finished_ack_from.size().string().cstring())
  //   if should_send_upstream() then
  //     @printf[I32]("!@ should_send_upstream\n".cstring())
  //     _upstream_requester.receive_finished_ack(upstream_request_id)
  //     if _custom_actions.contains(requester_id)
  //   //!@
  //   else
  //     @printf[I32]("!@ not should_send_upstream\n".cstring())
  //   end

