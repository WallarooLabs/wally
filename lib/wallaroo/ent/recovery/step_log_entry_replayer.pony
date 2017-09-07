/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"
use "wallaroo/core/topology"

primitive StepLogEntryReplayer
  fun apply(runner: Runner, deduplication_list: DeduplicationList,
    uid: U128, frac_ids: FractionalMessageId, statechange_id: U64,
    payload: ByteSeq val, this_step: Step)
  =>
    deduplication_list.push((uid, frac_ids))
    match runner
    | let r: ReplayableRunner =>
      r.replay_log_entry(uid, frac_ids, statechange_id, payload, this_step)
    else
      @printf[I32]("trying to replay a message to a non-replayable
      runner!".cstring())
    end
