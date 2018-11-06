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
use "serialise"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"

primitive StepStateMigrator
  fun receive_state(step: Step ref, runner: Runner, step_group: RoutingId,
    key: Key, state_bytes: ByteSeq val)
  =>
    ifdef "trace" then
      @printf[I32]("Received new state\n".cstring())
    end
    match runner
    | let r: SerializableStateRunner =>
      r.import_key_state(step, step_group, key, state_bytes)
    else
      Fail()
    end

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let state_bytes = r.export_key_state(step, key)
      boundary.migrate_key(id, step_group, key, checkpoint_id,
        state_bytes)
    else
      Fail()
    end
