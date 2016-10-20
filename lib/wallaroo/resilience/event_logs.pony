use "wallaroo/topology"
use "wallaroo/messages"

trait ResilientOrigin is Origin
  be replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
  be replay_finished()

//class LogEntry
//  //TODO-Alan: this object needs to go away
// replacement args: , uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val
//  let _uid: U64
//  let _frac_ids: (Array[U64] val | None)
//  let _statechange_id: U64
//  let _seq_id: U64
//  let _payload: Array[ByteSeq] val
//
//  new val create(uid': U64, frac_ids': (Array[U64] val | None),
//    statechange_id': U64, seq_id': U64,payload': Array[ByteSeq] val) =>
//    _uid = uid'
//    _frac_ids = frac_ids'
//    _statechange_id = statechange_id'
//    _payload = payload'
//    _seq_id = seq_id'
//
//  fun is_below_watermark(watermark: U64): Bool =>
//    //TODO: this will have to change once we have a Watermark type
//    _uid < watermark
//
//  fun uid(): U64 val => _uid
//  fun frac_ids(): (Array[U64] val | None) => _frac_ids
//  fun statechange_id(): U64 => _statechange_id
//  fun seq_id(): U64 => _seq_id
//  fun payload(): Array[ByteSeq] val => _payload

type LogEntry is (U64, (Array[U64] val | None), U64, Array[ByteSeq] val)

trait EventLogBuffer
   be queue(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
   be flush(watermark: U64)
   be set_id(id: U64)
   be replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val)
   be set_target(target: ResilientOrigin tag)
   be log_flushed(low_watermark: U64)
   be replay_finished()

actor DeactivatedEventLogBuffer is EventLogBuffer
  new create() => None
  be queue(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) => None
  be flush(watermark: U64) => None
  be set_id(id:U64) => None
  be replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) => None
  be set_target(target: ResilientOrigin tag) => None
  be log_flushed(low_watermark: U64) => None
  be replay_finished() => None

actor StandardEventLogBuffer is EventLogBuffer
  let _alfred: Alfred
  var _target: (ResilientOrigin tag | None)
  var _id: (U64 | None)
  var _buf: Array[LogEntry val] ref

  new create(alfred: Alfred) =>
    _buf = Array[LogEntry val]
    _alfred = alfred
    _id = None
    _alfred.register_log_buffer(this)
    _target = None

   be set_id(id:U64) =>
    _id = id

   be set_target(target: ResilientOrigin tag) =>
    _target = target

   be queue(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
    ifdef "resilience" then
      _buf.push((uid, frac_ids, statechange_id, payload))
    else
      //prevent a memory leak
      None
    end

   be flush(low_watermark: U64) =>
    match _id
    | let id: U64 =>
      let out_buf: Array[LogEntry val] iso = recover iso Array[LogEntry val] end 
      let new_buf: Array[LogEntry val] = Array[LogEntry val]
      for entry in _buf.values() do
        if entry._1 <= low_watermark then
            out_buf.push(entry)
        else
            new_buf.push(entry)
        end
      end
      _alfred.log(id,consume out_buf, low_watermark)
      _buf = new_buf
    end

  be log_flushed(low_watermark: U64) =>
    //TODO-Markus: update watermark tables wherever that may be, and send a watermark
    //upstream
    None

  be replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
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
