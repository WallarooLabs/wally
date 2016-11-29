use "collections"
use "time"
use "wallaroo/fail"
use "wallaroo/invariant"

class Routes
  """
  All the routes available
  """
  let _filter_route: _FilterRoute ref = recover ref _FilterRoute end
  let _routes: Map[RouteId, _Route] = _routes.create()
  var _flushed_watermark: U64 = 0
  var _flushing: Bool = false
  let _ack_batch_size: USize
  let _outgoing_to_incoming: _OutgoingToIncoming

  new create(ack_batch_size': USize = 100) =>
    _ack_batch_size = ack_batch_size'
    _outgoing_to_incoming = _OutgoingToIncoming(_ack_batch_size)

  fun ref add_route(route: Route) =>
    // This is our wedge into current routes until John
    // and I can work out the abstractions
    // Its used from Step
    ifdef debug then
      Invariant(not _routes.contains(route.id()))
    end

    _routes(route.id()) = _Route

  fun ref send(producer: Producer ref, o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    ifdef debug then
      Invariant(_routes.contains(o_route_id))
    end

    try
      _routes(o_route_id).send(o_seq_id)
      _add_incoming(producer, o_seq_id, i_origin, i_route_id, i_seq_id)
    else
      Fail()
    end

  fun ref filter(producer: Producer ref, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _filter_route.filter(o_seq_id)
    _add_incoming(producer, o_seq_id, i_origin, i_route_id, i_seq_id)

  fun ref receive_ack(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      Invariant(_routes.contains(route_id))
      LazyInvariant({()(_routes, route_id, seq_id): Bool ? =>
          _routes(route_id).highest_seq_id_sent() >= seq_id})
    end

    try
      _routes(route_id).receive_ack(seq_id)
    else
      Fail()
    end

  fun ref flushed(up_to: SeqId) =>
    ifdef debug then
      Invariant(_outgoing_to_incoming.contains(up_to))
    end

    try
      _flushing = false
      for (o_r, id) in
        _outgoing_to_incoming.origin_notifications(up_to).pairs()
      do
        o_r._1.update_watermark(o_r._2, id)
      end
      _outgoing_to_incoming.evict(up_to)
      _flushed_watermark = up_to
    else
      Fail()
    end

  fun ref _add_incoming(producer: Producer ref, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _outgoing_to_incoming.add(o_seq_id, i_origin, i_route_id, i_seq_id)
    _maybe_ack(producer)

  fun ref _maybe_ack(producer: Producer ref) =>
    if not _flushing and
      ((_outgoing_to_incoming.size() % _ack_batch_size) == 0)
    then
      _ack(producer)
    end

  fun ref _ack(producer: Producer ref) =>
    let proposed_watermark = propose_new_watermark()

    if proposed_watermark == _flushed_watermark then
      return
    end

    _flushing = true
    producer._flush(proposed_watermark)

  fun ref propose_new_watermark(): U64 =>
    let proposed_watermark = _ProposeWatermark(_filter_route, _routes)
    ifdef debug then
      Invariant(proposed_watermark >= _flushed_watermark)
    end
    proposed_watermark

// incorporate into TypedRoute
class _Route
  var _highest_seq_id_sent: U64 = 0
  var _highest_seq_id_acked: U64 = 0
  var _last_ack: U64 = Time.millis()

  fun ref send(o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(o_seq_id > _highest_seq_id_sent)
    end

    _highest_seq_id_sent = o_seq_id

  fun ref receive_ack(seq_id: SeqId) =>
    ifdef debug then
      Invariant(seq_id <= _highest_seq_id_sent)
    end

    _last_ack = Time.millis()
    _highest_seq_id_acked = seq_id

  fun is_fully_acked(): Bool =>
    _highest_seq_id_sent == _highest_seq_id_acked

  fun highest_seq_id_acked(): U64 =>
    _highest_seq_id_acked

  fun highest_seq_id_sent(): U64 =>
    _highest_seq_id_sent

class _FilterRoute
  var _highest_seq_id: U64 = 0

  fun ref filter(o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(o_seq_id > _highest_seq_id)
    end

    _highest_seq_id = o_seq_id

  fun is_fully_acked(): Bool =>
    true

  fun highest_seq_id(): U64 =>
    _highest_seq_id
