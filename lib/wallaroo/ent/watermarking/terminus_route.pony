/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/topology"
use "wallaroo/routing"

class TerminusRoute
  """
  End of the line route.

  We are leaving this process, to either another Wallaroo process
  or to an external system.

  The only route out of this step is to terminate here. Unlike filtering,
  termination can either be immediate (like filtering) or can be delayed
  such as "terminate this tuple once we know it has been sent by the sink".
  """
  var _highest_tracking_id_acked: U64 = 0
  let _ack_batch_size: USize
  var _tracking_id: U64 = 0
  let _tracking_id_to_incoming: _OutgoingToIncomingMessageTracker
  var _acked_watermark: U64 = 0
  var _ack_next_time: Bool = false

  // TODO: Change this to a reasonable value!
  new create(ack_batch_size': USize = 100) =>
    _ack_batch_size = ack_batch_size'
    _tracking_id_to_incoming =
      _OutgoingToIncomingMessageTracker(_ack_batch_size)

  fun ref terminate(i_producer: Producer, i_route_id: RouteId,
    i_seq_id: SeqId): SeqId
  =>
    """
    Mark for termination. Termination isn't complete until its acknowledged.
    """
    let id = _next_tracking_id()
    _tracking_id_to_incoming.add(id, i_producer, i_route_id, i_seq_id)

    id

  fun ref receive_ack(seq_id: SeqId) =>
    """
    Acknowledgement that we are done handling a termination.
    """
    ifdef debug then
      Invariant(seq_id <= _tracking_id)
    end

    _highest_tracking_id_acked = seq_id
    _maybe_ack()

  fun is_fully_acked(): Bool =>
    _tracking_id == _highest_tracking_id_acked

  fun ref _next_tracking_id(): U64 =>
    _tracking_id = _tracking_id + 1
    _tracking_id

  fun ref _maybe_ack() =>
    if ((_tracking_id_to_incoming._size() % _ack_batch_size) == 0) or
      _ack_next_time
    then
      if _highest_tracking_id_acked > _acked_watermark then
        _ack()
      end
    end

  fun ref _ack() =>
    let up_to = _highest_tracking_id_acked
    ifdef debug then
      Invariant(_tracking_id_to_incoming._contains(up_to))
    end

    for (o_r, id) in
      _tracking_id_to_incoming._producer_highs_below(up_to).pairs()
    do
      o_r._1.update_watermark(o_r._2, id)
    end
    _tracking_id_to_incoming.evict(up_to)
    _acked_watermark = up_to
    _ack_next_time = false

  fun ref request_ack() =>
    if _highest_tracking_id_acked > _acked_watermark then
      _ack()
    else
      _ack_next_time = true
    end
