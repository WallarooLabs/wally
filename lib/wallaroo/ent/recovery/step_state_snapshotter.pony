use "buffered"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

primitive StepStateSnapshotter
  fun apply(runner: Runner, id: StepId, seq_id_generator: StepSeqIdGenerator,
    event_log: EventLog, wb: Writer = Writer)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let serialized: ByteSeq val = r.serialize_state()
      wb.write(serialized)
      let payload = wb.done()
      let oid: StepId = id
      let uid: StepId = -1
      let statechange_id: U64 = -1
      let seq_id: U64 = seq_id_generator.last_id()
      event_log.snapshot_state(oid, uid, statechange_id, seq_id,
        consume payload)
    else
      @printf[I32](("Could not complete log rotation. StateRunner is not " +
        "Serializable.\n").cstring())
      Fail()
    end
