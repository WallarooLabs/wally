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

actor InitialInFlightAckRequester is InFlightAckRequester
  """
  Used when we are the initiator of a chain of in flight ack requests
  """
  let _step_id: StepId

  new create(step_id: StepId) =>
    _step_id = step_id

  be receive_in_flight_ack(request_id: RequestId) =>
    ifdef debug then
      @printf[I32](("Received in flight ack at InitialInFlightAckRequester. " +
        "This indicates the originator of a chain of in flight ack requests " +
        "has received the final ack. Request id received: %s.\n").cstring(),
        request_id.string().cstring())
    end
    None

  be receive_in_flight_resume_ack(request_id: RequestId) =>
    None

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None

actor EmptyInFlightAckRequester is InFlightAckRequester
  be receive_in_flight_ack(request_id: RequestId) =>
    None

  be receive_in_flight_resume_ack(request_id: RequestId) =>
    None

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None

class val InFlightResumeAckId
  """
  Every time we finish a messages in flight acking phase, one worker will
  generate a InFlightResumeAckId and broadcast messages telling every node
  that we are done with that phase. This id includes the id of the
  initiator of the request_in_flight_resume_ack messages and a seq_id that
  increments every time that initiator creates a new one for a new phase.
  """
  let initial_requester_id: StepId
  let seq_id: RequestId

  new val create(initial_requester_id': StepId, seq_id': RequestId) =>
    initial_requester_id = initial_requester_id'
    seq_id = seq_id'

  fun eq(other: InFlightResumeAckId): Bool =>
    (initial_requester_id == other.initial_requester_id) and
      (seq_id == other.seq_id)

class InFlightAckWaiter
  // This will be 0 for data receivers, router registry, and boundaries
  let _step_id: StepId
  let _id_gen: RequestIdGenerator = _id_gen.create()

  //////////////////
  // Finished Acks
  //////////////////
  // Map from the requester_id to the request id it sent us
  let _upstream_request_ids: Map[StepId, RequestId] =
    _upstream_request_ids.create()
  // Map from request_ids we generated to the requester_id for the
  // original upstream request they're related to
  let _downstream_request_ids: Map[RequestId, StepId] =
    _downstream_request_ids.create()
  let _pending_acks: Map[StepId, SetIs[RequestId]] = _pending_acks.create()
  let _upstream_requesters: Map[StepId, InFlightAckRequester] =
    _upstream_requesters.create()
  let _custom_actions: Map[StepId, CustomAction] = _custom_actions.create()

  /////////////////
  // Complete Ack Requests
  // For determining that all nodes have acknowledged that this round of
  // messages in flight acking is over.
  /////////////////
  var _in_flight_resume_ack_ids: Map[StepId, RequestId] =
    _in_flight_resume_ack_ids.create()
  let _pending_resume_acks: SetIs[RequestId] =
    _pending_resume_acks.create()
  let _upstream_resume_requesters: Map[StepId, InFlightAckRequester] =
    _upstream_resume_requesters.create()
  let _upstream_in_flight_resume_ack_ids: Map[StepId, RequestId] =
    _upstream_in_flight_resume_ack_ids.create()
  var _custom_resume_action: (CustomAction | None) = None

  // If this was part of a step that was migrated, then it should no longer
  // receive requests. This allows us to check that invariant.
  var _has_migrated: Bool = false

  new create(id: StepId = 0) =>
    _step_id = id

  fun ref migrated() =>
    """
    Indicates that an encapsulating step has been migrated to another worker.
    """
    _has_migrated = true

  fun ref initiate_request(initiator_id: StepId,
    custom_action: (CustomAction | None) = None)
  =>
    add_new_request(initiator_id, 0, InitialInFlightAckRequester(_step_id))
    match custom_action
    | let ca: CustomAction =>
      set_custom_action(initiator_id, ca)
    end

  fun ref add_new_request(requester_id: StepId, request_id: RequestId,
    upstream_requester': (InFlightAckRequester | None) = None,
    custom_action: (CustomAction | None) = None)
  =>
    let upstream_requester =
      match upstream_requester'
      | let far: InFlightAckRequester => far
      else
        EmptyInFlightAckRequester
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
      upstream_requester.receive_in_flight_ack(request_id)
    end

  fun ref initiate_resume_request(
    custom_action: (CustomAction | None) = None): InFlightResumeAckId
  =>
    _custom_resume_action = custom_action
    let new_req_id =
      try
        _in_flight_resume_ack_ids(_step_id)? + 1
      else
        1
      end
    _in_flight_resume_ack_ids(_step_id) = new_req_id
    InFlightResumeAckId(_step_id, new_req_id)

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

  fun ref unmark_consumer_request(request_id: RequestId) =>
    try
      let requester_id = _downstream_request_ids(request_id)?
      let id_set = _pending_acks(requester_id)?
      ifdef debug then
        Invariant(id_set.contains(request_id))
      end
      id_set.unset(request_id)
      _downstream_request_ids.remove(request_id)?
      _check_send_run(requester_id)
    else
      Fail()
    end

  fun ref try_finish_in_flight_request_early(requester_id: StepId) =>
    _check_send_run(requester_id)

  fun ref request_in_flight_resume_ack(
    in_flight_resume_ack_id: InFlightResumeAckId,
    request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester,
    custom_action: (CustomAction | None) = None): Bool
  =>
    """
    Return true if this is the first time we've seen this in_flight_resume_ack_id.
    """
    ifdef debug then
      Invariant(not _has_migrated)
    end

    let initial_requester_id = in_flight_resume_ack_id.initial_requester_id
    let seq_id = in_flight_resume_ack_id.seq_id

    ifdef debug then
      // Since a node should only send a request to its downstreams once during
      // a single request_in_flight_resume_ack phase, we should never see
      // the same upstream requester id twice in the same phase.
      Invariant(not _upstream_resume_requesters.contains(requester_id) and
        not _upstream_in_flight_resume_ack_ids.contains(requester_id))
    end
    _upstream_resume_requesters(requester_id) = requester
    _upstream_in_flight_resume_ack_ids(requester_id) = request_id

    match custom_action
    | let ca: CustomAction =>
      _custom_resume_action = ca
    end

    // We need to see if we have already handled this phase. If so, then
    // we return false. If this is the first time we've received this
    // InFlightResumeAckId, then we clear our old in flight ack data and
    // return true so that the encapsulating node can send requests
    // downstream. We should never send requests downstream more than
    // once for the same InFlightResumeAckId.
    if _in_flight_resume_ack_ids.contains(initial_requester_id) then
      try
        let current = _in_flight_resume_ack_ids(initial_requester_id)?
        if current < seq_id then
          ifdef debug then
            // We shouldn't be processing a new resume ack phase until
            // the last one is finished.
            Invariant(_pending_resume_acks.size() == 0)
          end
          _in_flight_resume_ack_ids(initial_requester_id) = seq_id
          _clear_in_flight_ack_data()
          true
        else
          // If we've already handled this in_flight_resume_ack_id then we
          // can immediately ack any new upstream requester since we know
          // we've forwarded the request to all our downstreams and that there
          // is one requester still waiting on our ack (which would prevent
          // an early termination of the algorithm).
          requester.receive_in_flight_resume_ack(request_id)
          try
            // Since we just acked this requester for this request_id, we need
            // to remove it from our upstream records.
            _upstream_resume_requesters.remove(requester_id)?
            _upstream_in_flight_resume_ack_ids.remove(requester_id)?
          else
            Fail()
          end
          false
        end
      else
        Fail()
        false
      end
    else
      ifdef debug then
        // We shouldn't be processing a new resume ack phase until
        // the last one is finished.
        Invariant(_pending_resume_acks.size() == 0)
      end
      _in_flight_resume_ack_ids(initial_requester_id) = seq_id
      _clear_in_flight_ack_data()
      true
    end

  fun ref add_consumer_resume_request(
    supplied_id: (RequestId | None) = None): RequestId
  =>
    let request_id =
      match supplied_id
      | let r_id: RequestId => r_id
      else
        _id_gen()
      end
    _pending_resume_acks.set(request_id)
    request_id

  fun ref unmark_consumer_resume_request(request_id: RequestId) =>
    if _pending_resume_acks.size() > 0 then
      _pending_resume_acks.unset(request_id)
      if _pending_resume_acks.size() == 0 then
        _resume_request_is_done()
      end
    end

  fun ref try_finish_resume_request_early() =>
    if _pending_resume_acks.size() == 0 then
      _resume_request_is_done()
    end

  fun ref _resume_request_is_done() =>
    for (requester_id, requester) in _upstream_resume_requesters.pairs() do
      try
        let upstream_request_id =
          _upstream_in_flight_resume_ack_ids(requester_id)?
        requester.receive_in_flight_resume_ack(upstream_request_id)
      else
        Fail()
      end
    end
    match _custom_resume_action
    | let ca: CustomAction =>
      ca()
      _custom_resume_action = None
    end
    _clear_resume_data()

  fun ref _clear_in_flight_ack_data() =>
    _pending_acks.clear()
    _downstream_request_ids.clear()
    _upstream_request_ids.clear()
    _upstream_requesters.clear()
    _custom_actions.clear()

  fun ref _clear_resume_data() =>
    _pending_resume_acks.clear()
    _upstream_resume_requesters.clear()
    _upstream_in_flight_resume_ack_ids.clear()
    _custom_resume_action = None

  fun report_status(code: ReportStatusCode) =>
    None

  fun ref _check_send_run(requester_id: StepId) =>
    try
      if _pending_acks(requester_id)?.size() == 0 then
        let upstream_request_id = _upstream_request_ids(requester_id)?
        _upstream_requesters(requester_id)?
          .receive_in_flight_ack(upstream_request_id)
        if _custom_actions.contains(requester_id) then
          _custom_actions(requester_id)?()
          _custom_actions.remove(requester_id)?
        end
      end
    else
      Fail()
    end
