use "collections"
use "time"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/topology"

class Routes
  """
  All the routes available
  """
  var _flushed_watermark: U64 = 0
  var _flushing: Bool = false
  let _ack_batch_size: USize
  let _outgoing_to_incoming: OutgoingToIncomingMessageTracker
  let _watermarker: Watermarker
  var _ack_next_time: Bool = false
  var _last_proposed_watermark: SeqId = 0


  // TODO: Change this to a reasonable value!
  new create(ack_batch_size': USize = 100) =>
    _ack_batch_size = ack_batch_size'
    _outgoing_to_incoming = OutgoingToIncomingMessageTracker(_ack_batch_size)
    _watermarker = Watermarker

  fun ref add_route(route: Route) =>
    _watermarker.add_route(route.id())

  fun ref remove_route(route: Route) =>
    _watermarker.remove_route(route.id())

  fun ref send(producer: Producer ref, o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _watermarker.sent(o_route_id, o_seq_id)
    _add_incoming(producer, o_seq_id, i_origin, i_route_id, i_seq_id)

  fun ref filter(producer: Producer ref, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _watermarker.filtered(o_seq_id)
    _add_incoming(producer, o_seq_id, i_origin, i_route_id, i_seq_id)
    _maybe_ack(producer)

  fun ref receive_ack(producer: Producer ref, route_id: RouteId,
    seq_id: SeqId)
  =>
    _watermarker.ack_received(route_id, seq_id)
    _maybe_ack(producer)

  fun ref flushed(up_to: SeqId) =>
    _flushing = false
    for (o_r, id) in
      _outgoing_to_incoming._origin_highs_below(up_to).pairs()
    do
      o_r._1.update_watermark(o_r._2, id)
    end
    _outgoing_to_incoming.evict(up_to)
    _flushed_watermark = up_to

  fun ref _add_incoming(producer: Producer ref, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _outgoing_to_incoming.add(o_seq_id, i_origin, i_route_id, i_seq_id)

  fun ref _maybe_ack(producer: Producer ref) =>
    if not _flushing and
      (((_outgoing_to_incoming._size() % _ack_batch_size) == 0) or
      _ack_next_time)
    then
      _ack(producer)
    end

  fun ref _ack(producer: Producer ref) =>
    let proposed_watermark = propose_new_watermark()

    if proposed_watermark <= _flushed_watermark then
      return
    end

    _flushing = true
    _ack_next_time = false
    producer._flush(proposed_watermark)

  fun ref request_ack(producer: Producer ref) =>
    _ack_next_time = true
    if not _flushing then
      _ack(producer)
    end

  fun ref propose_new_watermark(): U64 =>
    let proposed_watermark = _watermarker.propose_watermark()
    ifdef debug then
      Invariant(proposed_watermark >= _flushed_watermark)
    end
    _last_proposed_watermark = proposed_watermark
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
