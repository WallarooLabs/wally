/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "buffered"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"

primitive StepStateCheckpointer
  fun apply(runner: Runner, id: RoutingId, checkpoint_id: CheckpointId,
    event_log: EventLog, wb: Writer = Writer)
  =>
    @printf[I32]("!@ StepStateCheckpointer apply()\n".cstring())
    match runner
    | let r: SerializableStateRunner =>
      let serialized: ByteSeq val = r.serialize_state()
      @printf[I32]("!@ -- Got %s serialized bytes\n".cstring(), serialized.size().string().cstring())
      wb.write(serialized)
      let payload = wb.done()
      // @printf[I32]("!@ State Step %s calling EventLog.checkpoint_state()\n".cstring(), id.string().cstring())
      event_log.checkpoint_state(id, checkpoint_id, consume payload)
    else
      // Currently, non-state steps don't have anything to checkpoint.
      @printf[I32]("!@ Stateless Step %s calling EventLog.checkpoint_state()\n".cstring(), id.string().cstring())
      event_log.checkpoint_state(id, checkpoint_id,
        recover val Array[ByteSeq] end)
    end
