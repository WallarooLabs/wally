use "wallaroo/topology"
use "wallaroo/messages"

//TODO: origin needs to get its own file
trait ResilientOrigin is Origin
  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64, payload: ByteSeq)
  be replay_finished()
  be start_without_replay()

//TODO: explain in comment
type LogEntry is (U128, None, U64, U64, Array[ByteSeq] val)

trait EventLogBuffer
  fun ref queue(uid: U128, frac_ids: None,
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val)
  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64)

class DeactivatedEventLogBuffer is EventLogBuffer
  new create() => None
  fun ref queue(uid: U128, frac_ids: None,
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val) => None
  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64) => None

class StandardEventLogBuffer is EventLogBuffer
  let _alfred: Alfred
  let _origin_id: U128
  var _buf: Array[LogEntry val] ref

  new create(alfred: Alfred, id: U128) =>
    _buf = Array[LogEntry val]
    _alfred = alfred
    _origin_id = id

  fun ref queue(uid: U128, frac_ids: None,
    statechange_id: U64, seq_id: U64, payload: Array[ByteSeq] val) =>
    //prevent a memory leak by not pushing to _buf
    ifdef "resilience" then
      _buf.push((uid, frac_ids, statechange_id, seq_id, payload))
    end

  fun ref flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64, upstream_seq_id: U64) =>
    let out_buf: Array[LogEntry val] iso = recover iso Array[LogEntry val] end 
    let residual: Array[LogEntry val] = Array[LogEntry val]
    
    ifdef "resilience-debug" then
      @printf[I32]("_buf size: %llu\n".cstring(), _buf.size())
    end
    //TODO: post-paranoia, _buf is ordered so optimise w/ ring buffer-like thing
    for entry in _buf.values() do
      if entry._4 <= low_watermark then
        out_buf.push(entry)
      else
        residual.push(entry)
      end
    end
    ifdef "resilience-debug" then
      @printf[I32]("flush size: %llu\n".cstring(), out_buf.size())
    end
    _alfred.write_log(_origin_id, consume out_buf, low_watermark, origin,
      upstream_route_id, upstream_seq_id)
    _buf = residual
