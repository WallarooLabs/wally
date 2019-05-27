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
use "wallaroo/core/step"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

primitive StepRollbacker
  fun apply(payload: ByteSeq val, runner: Runner, step: Step ref,
    rb: Reader = Reader)
  =>
    rb.append(payload)
    try
      let w_bytes_size = rb.u32_be()?.usize()
      let watermarks_bytes = rb.block(w_bytes_size)?
      step.rollback_watermarks(consume watermarks_bytes)
      let s_bytes_size = rb.u32_be()?.usize()
      if s_bytes_size > 0 then
        let state_bytes = rb.block(s_bytes_size)?
        match runner
        | let r: RollbackableRunner =>
          ifdef "checkpoint_trace" then
            @printf[I32]("Step rolling back!\n".cstring())
          end
          r.rollback(consume state_bytes)
        else
          @printf[I32]("Trying to rollback on a non-rollbackable runner!"
            .cstring())
          Fail()
        end
      end
    else
      Fail()
    end
