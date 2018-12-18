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

use "buffered"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo/core/windows"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"

primitive StepStateCheckpointer
  fun apply(runner: Runner, id: RoutingId, checkpoint_id: CheckpointId,
    event_log: EventLog, watermarks: StageWatermarks, auth: AmbientAuth,
    wb: Writer = Writer)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("StepStateCheckpointer apply()\n".cstring())
    end
    let watermarks_bytes = StageWatermarksSerializer(watermarks, auth)
    wb.u32_be(watermarks_bytes.size().u32())
    wb.write(watermarks_bytes)
    let state_bytes =
      match runner
      | let r: SerializableStateRunner =>
        let serialized: ByteSeq val = r.serialize_state()
        ifdef "checkpoint_trace" then
          @printf[I32]("-- Got %s serialized bytes\n".cstring(),
            serialized.size().string().cstring())
        end
        serialized
      else
        // Currently, non-state steps don't have anything to checkpoint.
        ifdef "checkpoint_trace" then
          @printf[I32]("Stateless Step %s calling EventLog.checkpoint_state()\n"
            .cstring(), id.string().cstring())
        end
        recover val Array[U8] end
      end

    wb.u32_be(state_bytes.size().u32())
    if state_bytes.size() > 0 then
      wb.write(state_bytes)
    end

    event_log.checkpoint_state(id, checkpoint_id, wb.done())
