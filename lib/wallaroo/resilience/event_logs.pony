use "wallaroo/topology"
use "wallaroo/messages"

trait ResilientOrigin is Origin
  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
  be replay_finished()
  be start_without_replay()
  be set_id(id: U128)

type LogEntry is (U128, (Array[U64] val | None), U64, U64, Array[ByteSeq] val)

trait EventLogBuffer
  fun ref queue(uid: U128, frac_ids: (Array[U64] val | None),
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val)
  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64)

class DeactivatedEventLogBuffer is EventLogBuffer
  new create() => None
  fun ref queue(uid: U128, frac_ids: (Array[U64] val | None),
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val) => None
  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64) => None

class StandardEventLogBuffer is EventLogBuffer
  let _alfred: Alfred
  let _id: U128
  var _buf: Array[LogEntry val] ref

  new create(alfred: Alfred, id: U128) =>
    _buf = Array[LogEntry val]
    _alfred = alfred
    _id = id

  fun ref queue(uid: U128, frac_ids: (Array[U64] val | None),
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val) =>
    ifdef "resilience" then
      _buf.push((uid, frac_ids, statechange_id, seq_id, payload))
    else
      //prevent a memory leak
      None
    end

  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64) =>
    let out_buf: Array[LogEntry val] iso = recover iso Array[LogEntry val] end 
    let new_buf: Array[LogEntry val] = Array[LogEntry val]
    
    for entry in _buf.values() do
      if entry._4 <= low_watermark then
        out_buf.push(entry)
      else
        new_buf.push(entry)
      end
    end
    _alfred.write_log(_id, consume out_buf, low_watermark, origin,
      upstream_route_id, upstream_seq_id)
    _buf = new_buf
