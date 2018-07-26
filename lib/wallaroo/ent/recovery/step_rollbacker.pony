/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"
use "wallaroo/core/topology"

primitive StepRollbacker
  fun apply(payload: ByteSeq val, runner: Runner) =>
    match runner
    | let r: RollbackableRunner =>
      r.rollback(payload)
    else
      @printf[I32]("trying to rollback on a non-rollbackable runner!"
        .cstring())
    end
