use "wallaroo/topology"
use "wallaroo/messages"

interface EventLogBufferable
  fun ref set_buffer_target(target: ResilientOrigin tag)

trait ResilientOrigin is Origin
  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
  be replay_finished()
  be log_flushed(low_watermark: U64, messages_flushed: U64)
  be start_without_replay()

type LogEntry is (U128, (Array[U64] val | None), U64, Array[ByteSeq] val)

trait EventLogBuffer
  be queue(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
  be flush(watermark: U64)
  be set_id(id: U128)
  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
  be set_target(target: ResilientOrigin tag)
  be log_flushed(low_watermark: U64, messages_flushed: U64)
  be replay_finished()
  be start_without_replay()

actor DeactivatedEventLogBuffer is EventLogBuffer
  new create() => None
  be queue(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) => None
  be flush(watermark: U64) => None
  be set_id(id: U128) => None
  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) => None
  be set_target(target: ResilientOrigin tag) => None
  be log_flushed(low_watermark: U64, messages_flushed: U64) => None
  be replay_finished() => None
  be start_without_replay() => None

actor StandardEventLogBuffer is EventLogBuffer
  let _alfred: Alfred
  var _target: (ResilientOrigin tag | None)
  var _id: (U128 | None)
  var _buf: Array[LogEntry val] ref

  new create(alfred: Alfred) =>
    _buf = Array[LogEntry val]
    _alfred = alfred
    _id = None
    _alfred.register_log_buffer(this)
    _target = None

   be set_id(id: U128) =>
    _id = id

   be set_target(target: ResilientOrigin tag) =>
    _target = target

   be queue(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
    ifdef "resilience" then
      _buf.push((uid, frac_ids, statechange_id, payload))
    else
      //prevent a memory leak
      None
    end

   be flush(low_watermark: U64) =>
    match _id
    | let id: U128 =>
      let out_buf: Array[LogEntry val] iso = recover iso Array[LogEntry val] end 
      let new_buf: Array[LogEntry val] = Array[LogEntry val]
      
      // TODO: fractional uids
      for entry in _buf.values() do
        if entry._1 <= low_watermark.u128() then
          out_buf.push(entry)
        else
          new_buf.push(entry)
        end
      end
      _alfred.log(id, consume out_buf, low_watermark)
      _buf = new_buf
    else
      @printf[I32]("flushing an uninitialised buffer has no effect".cstring())
    end

  be log_flushed(low_watermark: U64, messages_flushed: U64) =>
    match _target
    | let t: ResilientOrigin tag => t.log_flushed(low_watermark, messages_flushed)
    else
      //TODO: explode
      @printf[I32]("FATAL: received log_flushed with None target".cstring())
    end

  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
    match _target
    | let t: ResilientOrigin tag => t.replay_log_entry(uid, frac_ids, statechange_id, payload)
    else
      //TODO: explode
      @printf[I32]("FATAL: trying to replay event log to a None target".cstring())
    end

  be replay_finished() =>
    match _target
    | let t: ResilientOrigin tag => t.replay_finished()
    else
      //TODO: explode
      @printf[I32]("FATAL: trying to terminate replay log to a None target".cstring())
    end

  be start_without_replay() =>
    match _target
    | let t: ResilientOrigin tag => t.start_without_replay()
    else
      //TODO: explode
      @printf[I32]("FATAL: trying to terminate replay log to a None target".cstring())
    end
