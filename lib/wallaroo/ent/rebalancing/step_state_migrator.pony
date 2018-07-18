/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "serialise"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

class val ShippedState
  let state_bytes: ByteSeq val
  let pending_messages: Array[QueuedStepMessage] val

  new create(state_bytes': ByteSeq val,
    pending_messages': Array[QueuedStepMessage] val)
  =>
    state_bytes = state_bytes'
    pending_messages = pending_messages'

primitive StepStateMigrator
  fun receive_state(runner: Runner, state: ByteSeq val)
  =>
    ifdef "trace" then
      @printf[I32]("Received new state\n".cstring())
    end
    match runner
    | let r: SerializableStateRunner =>
      r.replace_serialized_state(state)
    else
      Fail()
    end

//!@
  // fun send_state_to_neighbour(runner: Runner, neighbour: Step,
  //   p_ms: Array[QueuedStepMessage], auth: AmbientAuth)
  // =>
  //   match runner
  //   | let r: SerializableStateRunner =>
  //     let pending_messages = recover iso Array[QueuedStepMessage] end
  //     for m in p_ms.values() do
  //       pending_messages.push(m)
  //     end
  //     let shipped_state = ShippedState(r.serialize_state(),
  //       consume pending_messages)
  //     let shipped_state_bytes =
  //       try
  //         Serialised(SerialiseAuth(auth), shipped_state)?
  //           .output(OutputSerialisedAuth(auth))
  //       else
  //         Fail()
  //         recover val Array[U8] end
  //       end
  //     neighbour.receive_state(shipped_state_bytes)
  //   else
  //     Fail()
  //   end

  fun send_state(runner: Runner, id: StepId, boundary: OutgoingBoundary,
    state_name: String, key: Key, p_ms: Array[QueuedStepMessage],
    auth: AmbientAuth)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let pending_messages = recover iso Array[QueuedStepMessage] end
      for m in p_ms.values() do
        pending_messages.push(m)
      end
      let shipped_state = ShippedState(r.serialize_state(),
        consume pending_messages)
      let shipped_state_bytes =
        try
          Serialised(SerialiseAuth(auth), shipped_state)?
            .output(OutputSerialisedAuth(auth))
        else
          Fail()
          recover val Array[U8] end
        end
      boundary.migrate_step(id, state_name, key, shipped_state_bytes)
    else
      Fail()
    end
