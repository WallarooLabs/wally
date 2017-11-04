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

use "buffered"
use "collections"
use "time"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/routing"
use "wallaroo/core/state"

trait BasicComputation
  fun name(): String

interface Computation[In: Any val, Out: Any val] is BasicComputation
  fun apply(input: In): (Out | Array[Out] val | None)
  fun name(): String

interface StateComputation[In: Any val, Out: Any val, S: State ref] is
  BasicComputation
  // Return a tuple containing the result of the computation (which is None
  // if there is no value to forward) and a StateChange if there was one (or
  // None to indicate no state change).
  fun apply(input: In, sc_repo: StateChangeRepository[S], state: S):
    ((Out | Array[Out] val | None),
     (StateChange[S] ref | DirectStateChange | None))

  fun name(): String

  fun state_change_builders(): Array[StateChangeBuilder[S]] val

trait val StateProcessor[S: State ref] is BasicComputation
  fun name(): String
  // Return a tuple containing a Bool indicating whether the message was
  // finished processing here, a Bool indicating whether a route can still
  // keep receiving data and the state change (or None if there was
  // no state change).
  fun apply(state: S, sc_repo: StateChangeRepository[S],
    omni_router: OmniRouter, metric_name: String, pipeline_time_spent: U64,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64):
    (Bool, Bool, (StateChange[S] ref | DirectStateChange | None), U64,
      U64, U64)

trait InputWrapper
  fun input(): Any val

class val StateComputationWrapper[In: Any val, Out: Any val, S: State ref]
  is (StateProcessor[S] & InputWrapper)
  let _state_comp: StateComputation[In, Out, S] val
  let _input: In
  let _target_id: U128

  new val create(input': In, state_comp: StateComputation[In, Out, S] val,
    target_id: U128) =>
    _state_comp = state_comp
    _input = input'
    _target_id = target_id

  fun input(): Any val => _input

  fun apply(state: S, sc_repo: StateChangeRepository[S],
    omni_router: OmniRouter, metric_name: String, pipeline_time_spent: U64,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64):
    (Bool, Bool, (StateChange[S] ref | DirectStateChange | None), U64,
      U64, U64)
  =>
    let computation_start = Time.nanos()
    let result = _state_comp(_input, sc_repo, state)
    let computation_end = Time.nanos()

    // It matters that the None check comes first, since Out could be
    // type None if you always filter/end processing there
    match result
    | (None, _) => (true, true, result._2, computation_start,
        computation_end, computation_end) // This must come first
    | (let output: Out, _) =>
      (let is_finished, let keep_sending, let last_ts) = omni_router.route_with_target_id[Out](
        _target_id, metric_name, pipeline_time_spent, output, producer,
        i_msg_uid, frac_ids, computation_end, metrics_id, worker_ingress_ts)

      (is_finished, keep_sending, result._2, computation_start,
        computation_end, last_ts)
      | (let outputs: Array[Out] val, _) =>
          var this_is_finished = true
          var this_last_ts = computation_end
          // this is unused and kept here only for short term posterity until
          // https://github.com/WallarooLabs/wallaroo/issues/1010 is addressed
          let this_keep_sending = true

          for (frac_id, output) in outputs.pairs() do
            let o_frac_ids = match frac_ids
            | None =>
              recover val
                Array[U32].init(frac_id.u32(), 1)
              end
            | let x: Array[U32 val] val =>
              recover val
                let z = Array[U32](x.size() + 1)
                for xi in x.values() do
                  z.push(xi)
                end
                z.push(frac_id.u32())
                z
              end
            end

            (let f, let s, let ts) =
              omni_router.route_with_target_id[Out](
                _target_id, metric_name, pipeline_time_spent, output, producer,
                i_msg_uid, o_frac_ids,
                computation_end, metrics_id, worker_ingress_ts)

            // we are sending multiple messages, only mark this message as
            // finished if all are finished
            if (f == false) then
              this_is_finished = false
            end

            this_last_ts = ts
          end
          (this_is_finished, this_keep_sending, result._2,
            computation_start, computation_end, this_last_ts)
    else
      (true, true, result._2, computation_start, computation_end,
        computation_end)
    end

  fun name(): String => _state_comp.name()

interface val BasicComputationBuilder
  fun apply(): BasicComputation val

interface val ComputationBuilder[In: Any val, Out: Any val]
  fun apply(): Computation[In, Out] val

interface val StateBuilder[S: State ref]
  fun apply(): S
  fun name(): String
