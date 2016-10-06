use "collections"


class MsgEnvelope
  let origin_tag: Step tag    // tag pointing to upstream origin for msg
  let msg_uid: U64            // Source assigned UID; universally unique
  let seq_id: U64             // immediate origin assigned sequence id for this msg
  let route_id: U64           // route id assigned by immediate upstream origin

  new val create(origin_tag': Step tag, seq_id': U64, route_id': U64)
  =>
    origin_tag = origin_tag'
    seq_id = seq_id'
    route_id = route_id'

class HighWaterMarkTable
  """
  Keep track of a high watermark for each message coming into a step.
  We store the seq_id as assigned to a message by the upstream origin
  that sent the message.
  """
  let _hwmt: Array[U64, U64][U64]  // tuple access to high watermark

  fun updateHighWatermark(origin_tag: U64, route_id: U64, seq_id: U64)
  =>
    _hwmt(origin_tag, route_id) = seq_id
    

class TranslationTable
  """
  We need to be able to go from an incoming seq_id to an outgoing seq_id and
  vice versa.
  Create a new entry every time we send a message downstream.
  Remove old entries every time we receive a new low watermark.
  """

class LowWaterMarkTable
  """
  Keep track of low watermark values per route as reported by downstream steps.
  """
  let _lwmt: blabla

  fun updateLowWatermark(route_id: U64, seq_id: U64)
  =>
    _lwmt(route_id) = seq_id

    
