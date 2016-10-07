use "collections"
use "wallaroo/topology"


class MsgEnvelope
  let origin_tag: Step tag // tag referencing upstream origin for msg
  let msg_uid: U64         // Source assigned UID; universally unique
  let seq_id: U64          // assigned by immediate upstream origin
  let route_id: U64        // assigned by immediate upstream origin

  new val create(origin_tag': Step tag, msg_uid': U64,
    seq_id': U64, route_id': U64)
  =>
    origin_tag = origin_tag'
    msg_uid = msg_uid'
    seq_id = seq_id'
    route_id = route_id'

    
class HighWaterMarkTable
  """
  Keep track of a high watermark for each message coming into a step.
  We store the seq_id as assigned to a message by the upstream origin
  that sent the message.
  """
  let _hwmt: HashMap[(U64, U64), U64, HashIs[(U64, U64)]] =
    HashMap[(U64, U64), U64, HashIs[(U64, U64)]]()
  // tuple access to high watermark

  fun ref updateHighWatermark(origin_tag: U64, route_id: U64, seq_id: U64)
  =>
    try
      _hwmt.upsert((origin_tag, route_id), seq_id,
        lambda(x: U64, y: U64): U64 =>  y end)
    else
      @printf[I32]("Error upserting into _hwmt\n".cstring())      
    end

class TranslationTable
  """
  We need to be able to go from an incoming seq_id to an outgoing seq_id and
  vice versa.
  Create a new entry every time we send a message downstream.
  Remove old entries every time we receive a new low watermark.
  """
  let _inToOut: HashMap[U64, U64, HashEq[U64]] =
    HashMap[U64, U64, HashEq[U64]]()
  let _outToIn: HashMap[U64, U64, HashEq[U64]] =
    HashMap[U64, U64, HashEq[U64]]()
  
  fun ref update(in_seq_id: U64, out_seq_id: U64)
  =>
    try
      _inToOut.insert(in_seq_id, out_seq_id)
      _outToIn.insert(out_seq_id, in_seq_id)
    else
      @printf[I32]("Error inserting into translation tables\n".cstring())      
    end

  fun outToIn(out_seq_id: U64): U64
  =>
    """
    Return the incoming seq_id for a given outgoing seq_id.
    """
    try
      _outToIn(out_seq_id)
    else
      @printf[I32]("Error in outToIn\n".cstring())
      0
    end

  fun inToOut(in_seq_id: U64): U64
  =>
    """
    Return the outgoing seq_id for a given incoming seq_id.
    """
    try
      _inToOut(in_seq_id)
    else
      @printf[I32]("Error in inToOut\n".cstring())
      0
    end

  fun ref remove(out_seq_id: U64)
  =>
    try
      _inToOut.remove(_outToIn(out_seq_id))
      _outToIn.remove(out_seq_id)
    else
      @printf[I32]("Error in remove\n".cstring())
    end

class LowWaterMarkTable
  """
  Keep track of low watermark values per route as reported by downstream 
  steps.
  """
  let _lwmt: Array[U64] = Array[U64]()

  fun ref updateLowWatermark(route_id: U64, seq_id: U64)
  =>
    _lwmt(route_id) = seq_id


    
