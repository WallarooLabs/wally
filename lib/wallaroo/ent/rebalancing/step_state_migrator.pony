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
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"

primitive StepStateMigrator
  fun receive_state(step: Step ref, runner: Runner, state_name: StateName,
    key: Key, state_bytes: ByteSeq val)
  =>
    ifdef "trace" then
      @printf[I32]("Received new state\n".cstring())
    end
    match runner
    | let r: SerializableStateRunner =>
      r.import_key_state(step, state_name, key, state_bytes)
    else
      Fail()
    end

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, state_name: String, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let state_bytes = r.export_key_state(step, key)
      @printf[I32]("!@ READY TO EXPORT %s bytes for key %s\n".cstring(), state_bytes.size().string().cstring(), key.cstring())
      boundary.migrate_key(id, state_name, key, checkpoint_id,
        state_bytes)
    else
      Fail()
    end
