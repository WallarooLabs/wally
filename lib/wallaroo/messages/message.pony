use "collections"
use "wallaroo/topology"

trait Origin
  fun tag hash(): U64 =>
    (digestof this).hash()

  fun ref _hwm_get(): HighWatermarkTable
  fun ref _lwm_get(): LowWatermarkTable
  fun ref _translate_get(): TranslationTable
  fun ref _origins_get(): OriginSet
    
  fun ref _bookkeeping(incoming_envelope: MsgEnvelope box,
    outgoing_envelope: MsgEnvelope box)
  =>
    """
    Process envelopes and keep track of things
    """
    match incoming_envelope.origin
    | let origin: Origin tag =>
      // keep track of messages we've sent downstream
      _hwm_get().update((origin, outgoing_envelope.route_id),
        outgoing_envelope.seq_id)
      // keep track of mapping between incoming / outgoing seq_id
      _translate_get().update(incoming_envelope.seq_id,
        outgoing_envelope.seq_id )
      // keep track of origins
      _origins_get().set(origin)
    end
    
  fun ref _update_watermark(route_id: U64, seq_id: U64)
  =>
  """
  Process a high watermark received from a downstream step.
  TODO: receive watermark, flush buffers and send another watermark
  """
  try
    // translate downstream seq_id to origin's seq_id
    let origin_seq_id = _translate_get().outToIn(seq_id)
    // update low watermark for this route_id
    _lwm_get().update(route_id, origin_seq_id)
  else
    @printf[I32]("Error finding value in TranslationTable\n".cstring())
  end
  // report low watermark to all upstream origins
  for origin in _origins_get().values() do
    //   origin.update_watermark(_lwm.low_watermark())
    None
  end

    
type OriginSet is HashSet[Origin tag, HashIs[Origin tag]] 
    
class MsgEnvelope
  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary  
  var origin: (Origin tag | None)   // tag referencing upstream origin for msg
  var msg_uid: U128         // Source assigned UID; universally unique
  var frac_ids: (Array[U64] val | None) // fractional msg ids
  var seq_id: U64          // assigned by immediate upstream origin
  var route_id: U64        // assigned by immediate upstream origin

  new create(origin': (Origin tag | None), msg_uid': U128,
    frac_ids': (Array[U64] val | None), seq_id': U64, route_id': U64)
  =>
    origin = origin'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    seq_id = seq_id'
    route_id = route_id'

  fun ref update(origin': (Origin tag | None), msg_uid': U128, 
    frac_ids': (Array[U64] val | None), seq_id': U64, route_id': U64 = 0) 
  =>
    origin = origin'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    seq_id = seq_id'
    route_id = route_id'

  fun clone(): MsgEnvelope val =>
    match frac_ids
    | let f_ids: Array[U64] val =>
      recover val MsgEnvelope(origin, msg_uid, recover val f_ids.clone() end,
        seq_id,route_id) end
    else
      recover val MsgEnvelope(origin, msg_uid, frac_ids, seq_id, route_id) end
    end


primitive HashTuple
  fun hash(t: (U64, U64)): U64 =>
    cantorPair(t)

  fun eq(t1: (U64, U64), t2: (U64, U64)): Bool =>
    cantorPair(t1) == cantorPair(t2)

  fun cantorPair(t: (U64, U64)): U64 =>
    (((t._1 + t._2) * (t._1 + t._2 + 1)) / 2 )+ t._2    

    
type OriginRoutePair is (Origin tag, U64)


primitive HashOriginRoute
  fun hash(t: OriginRoutePair): U64
  =>
    cantorPair((t._1.hash(), t._2.hash()))

  fun eq(t1: OriginRoutePair, t2: OriginRoutePair): Bool
  =>
    hash(t1) == hash(t2)

  fun cantorPair(t: (U64, U64)): U64 =>
    (((t._1 + t._2) * (t._1 + t._2 + 1)) / 2 )+ t._2    
    

class HighWatermarkTable
  """
  Keep track of a high watermark for each message coming into a step.
  We store the seq_id as assigned to a message by the upstream origin
  that sent the message.
  TODO: Make this a proper table with (Origin, Route) -> seq_id instead
        of a hashmap. We know that the number of origins and routes is
        smallish and can be derived from the topology object. The size
        of this table is static.
  """
  let _hwmt: HashMap[OriginRoutePair, U64, HashOriginRoute]
  
  new create(size: USize)
  =>
    _hwmt = HashMap[OriginRoutePair, U64, HashOriginRoute](size)
     
  fun ref update(key: OriginRoutePair, seq_id: U64)
  =>
  """
  Keep track of the highest seq_id per route per origin.
  """  
    try
      _hwmt.upsert(key, seq_id, lambda(x: U64, y: U64): U64
      =>
        if y > x then
          y
        else
          x
        end
      end)
    else
      @printf[I32]("Error upserting into HighWaterMarkTable\n".cstring())      
    end

  fun apply(key: OriginRoutePair): U64 ?
  =>
    try
      _hwmt(key)
    else
      @printf[I32]("Error fetching a seq_id from HighWaterMarkTable\n".cstring())
      error
    end


class TranslationTable
  """
  We need to be able to go from an incoming seq_id to an outgoing seq_id and
  vice versa.
  Create a new entry every time we send a message downstream.
  Remove old entries every time we receive a new low watermark.

  TODO: Extend this to support splits.
        _inToOut: Map[U64, Set[U64]]
        _outToIn: Map[U64, U64]
  """
  let _inToOut: Map[U64, U64]
  let _outToIn: Map[U64, U64]

  new create(size: USize)
  =>
    _inToOut = Map[U64, U64](size)
    _outToIn = Map[U64, U64](size)
      
  fun ref update(in_seq_id: U64, out_seq_id: U64)
  =>
    try
      _inToOut.insert(in_seq_id, out_seq_id)
      _outToIn.insert(out_seq_id, in_seq_id)
    else
      @printf[I32]("Error inserting into translation tables\n".cstring())      
    end

  fun outToIn(out_seq_id: U64): U64 ?
  =>
    """
    Return the incoming seq_id for a given outgoing seq_id.
    """
    try
      _outToIn(out_seq_id)
    else
      @printf[I32]("Error in outToIn: %ld\n".cstring(), out_seq_id)
      error
    end

  fun inToOut(in_seq_id: U64): U64 ?
  =>
    """
    Return the outgoing seq_id for a given incoming seq_id.
    """
    try
      _inToOut(in_seq_id)
    else
      @printf[I32]("Error in inToOut: %ld\n".cstring(), in_seq_id)
      error
    end

  fun ref remove(out_seq_id: U64)
  =>
    try
      _inToOut.remove(_outToIn(out_seq_id))
      _outToIn.remove(out_seq_id)
    else
      @printf[I32]("Error removing key from TranslationTable\n".cstring())
    end

class LowWatermarkTable
  """
  Keep track of low watermark values per route as reported by downstream 
  steps.
  """
  let _lwmt: Map[U64, U64]
  var _low_watermark: U64
  
  new create(size: USize)
  =>
    _lwmt = Map[U64, U64](size)
    _low_watermark = U64(0)
    
  fun ref update(route_id: U64, seq_id: U64)
  =>
    _lwmt(route_id) = seq_id
    _new_low_watermark(seq_id)

  fun ref _new_low_watermark(seq_id: U64)
  =>
    var min = seq_id
    for value in _lwmt.values() do
      if value < min then
        min = value
      end
    end
    _low_watermark = min
    
  fun apply(route_id: U64): U64 ?
  =>
    try
      _lwmt(route_id)
    else
      @printf[I32]("Error fetching a seq_id from LowWaterMarkTable\n".cstring())
      error
    end

  fun ref remove(route_id: U64)
  =>
    try
      _lwmt.remove(route_id)
    else
      @printf[I32]("Error removing key from LowWaterMarkTable\n".cstring())
    end

  fun low_watermark(): U64
  =>
    _low_watermark


  
