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
use "wallaroo/ent/snapshot"
use "wallaroo_labs/mort"

primitive StepStateSnapshotter
  fun apply(runner: Runner, id: RoutingId, snapshot_id: SnapshotId,
    event_log: EventLog, wb: Writer = Writer)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let serialized: ByteSeq val = r.serialize_state()
      wb.write(serialized)
      let payload = wb.done()
      event_log.snapshot_state(id, snapshot_id, consume payload)
    else
      // Currently, non-state steps don't have anything to snapshot.
      event_log.snapshot_state(id, snapshot_id,
        recover val Array[ByteSeq] end)
    end
