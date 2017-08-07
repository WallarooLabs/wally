use "time"
use "wallaroo/invariant"
use "wallaroo/routing"

class Acker
  """
  Handles coordination between different moving parts that are used to
  when making decisions of what messages to acknowledge having been handled.
  """
  var _flushed_watermark: U64 = 0
  var _flushing: Bool = false
  let _ack_batch_size: USize
  var _ack_next_time: Bool = false
  var _last_proposed_watermark: SeqId = 0
  let _outgoing_to_incoming: OutgoingToIncomingMessageTracker
  let _watermarker: Watermarker

  // TODO: Change this to a reasonable value!
  new create(ack_batch_size': USize = 100) =>
    _ack_batch_size = ack_batch_size'
    _outgoing_to_incoming = OutgoingToIncomingMessageTracker(_ack_batch_size)
    _watermarker = Watermarker

  fun ref add_route(route: Route) =>
    _watermarker.add_route(route.id())

  fun ref remove_route(route: Route) =>
    _watermarker.remove_route(route.id())

  fun ref sent(o_route_id: RouteId, o_seq_id: SeqId) =>
    _watermarker.sent(o_route_id, o_seq_id)

  fun ref filtered(producer: Producer ref, o_seq_id: SeqId)
  =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _watermarker.filtered(o_seq_id)
    // TO DO: one to many. _maybe_ack feels weird here.
    _maybe_ack(producer)

  fun ref ack_received(producer: Producer ref, route_id: RouteId,
    seq_id: SeqId)
  =>
    _watermarker.ack_received(route_id, seq_id)
    _maybe_ack(producer)

  fun ref track_incoming_to_outgoing(producer: Producer ref, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _add_incoming(producer, o_seq_id, i_origin, i_route_id, i_seq_id)

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
    producer.flush(proposed_watermark)

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
