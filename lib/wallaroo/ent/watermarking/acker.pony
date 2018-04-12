/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "time"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/routing"

class Acker
  """
  Handles coordination between different moving parts that are used to
  when making decisions of what messages to acknowledge having been handled.
  """
  var _last_watermark_sent_to_log: U64 = 0
  var _flushing: Bool = false
  let _ack_batch_size: USize
  var _ack_next_time: Bool = false
  let _outgoing_to_incoming: _OutgoingToIncomingMessageTracker
  let _watermarker: Watermarker = Watermarker

  // TODO: Change this to a reasonable value!
  new create(ack_batch_size': USize = 100) =>
    _ack_batch_size = ack_batch_size'
    _outgoing_to_incoming = _OutgoingToIncomingMessageTracker(_ack_batch_size)

  fun ref add_route(route: Route) =>
    _watermarker.add_route(route.id())

  fun contains_route(route: Route): Bool =>
    _watermarker.contains_route(route.id())

  fun ref remove_route(route: Route) =>
    _watermarker.remove_route(route.id())

  fun routes_size(): USize =>
    _watermarker.routes_size()

  fun ref sent(o_route_id: RouteId, o_seq_id: SeqId) =>
    _watermarker.sent(o_route_id, o_seq_id)

  fun ref filtered(ackable: Ackable ref, o_seq_id: SeqId)
  =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _watermarker.filtered(o_seq_id)
    // TO DO: one to many. _maybe_ack feels weird here.
    _maybe_ack(ackable)

  fun ref ack_received(ackable: Ackable ref, route_id: RouteId,
    seq_id: SeqId)
  =>
    _watermarker.ack_received(route_id, seq_id)
    _maybe_ack(ackable)

  fun ref track_incoming_to_outgoing(o_seq_id: SeqId, i_producer: Producer,
    i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _add_incoming(o_seq_id, i_producer, i_route_id, i_seq_id)

  fun ref flushed(up_to: SeqId) =>
    _flushing = false
    for (o_r, id) in
      _outgoing_to_incoming._producer_highs_below(up_to).pairs()
    do
      o_r._1.update_watermark(o_r._2, id)
    end
    _outgoing_to_incoming.evict(up_to)

  fun ref _add_incoming(o_seq_id: SeqId, i_producer: Producer,
    i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _outgoing_to_incoming.add(o_seq_id, i_producer, i_route_id, i_seq_id)

  fun ref _maybe_ack(ackable: Ackable ref) =>
    if not _flushing and
      (((_outgoing_to_incoming._size() % _ack_batch_size) == 0) or
      _ack_next_time)
    then
      _ack(ackable)
    end

  fun ref _ack(ackable: Ackable ref) =>
    let proposed_watermark = propose_new_watermark()

    if proposed_watermark > _last_watermark_sent_to_log then
      _last_watermark_sent_to_log = proposed_watermark
      _flushing = true
      _ack_next_time = false
      ackable.flush(proposed_watermark)
    end


  fun ref request_ack(ackable: Ackable ref) =>
    _ack_next_time = true
    if not _flushing then
      _ack(ackable)
    end

  fun ref propose_new_watermark(): U64 =>
    let proposed_watermark = _watermarker.propose_watermark()
    proposed_watermark
