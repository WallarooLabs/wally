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
use "wallaroo_labs/mort"

primitive StepStateSnapshotter
  fun apply(runner: Runner, id: RoutingId, seq_id_generator: StepSeqIdGenerator,
    event_log: EventLog, wb: Writer = Writer)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let serialized: ByteSeq val = r.serialize_state()
      wb.write(serialized)
      let payload = wb.done()
      let oid: RoutingId = id
      let uid: RoutingId = -1
      let statechange_id: U64 = -1
      let seq_id: U64 = seq_id_generator.last_id()
      event_log.snapshot_state(oid, uid, statechange_id, seq_id,
        consume payload)
    else
      @printf[I32](("Could not complete log rotation. StateRunner is not " +
        "Serializable.\n").cstring())
      Fail()
    end
