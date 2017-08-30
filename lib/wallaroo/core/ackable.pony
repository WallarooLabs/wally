use "collections"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/watermarking"
use "wallaroo/routing"
use "wallaroo/topology"

trait tag Ackable
  fun ref _acker(): Acker

  // TO DO: temporary one to many change to make this public
  fun ref flush(low_watermark: SeqId)

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  =>
    None

  be log_flushed(low_watermark: SeqId) =>
    """
    We will be called back here once the eventlogs have been flushed for a
    particular producer. We can now send the low watermark upstream to this
    producer.
    """
    _acker().flushed(low_watermark)

  fun ref bookkeeping(o_route_id: RouteId, o_seq_id: SeqId) =>
    """
    Process envelopes and keep track of things
    """
    ifdef "trace" then
      @printf[I32]("Bookkeeping called for route %llu\n".cstring(), o_route_id)
    end
    ifdef "resilience" then
      _acker().sent(o_route_id, o_seq_id)
    end

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    """
    Process a high watermark received from a downstream step.
    """
    _update_watermark(route_id, seq_id)

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]((
      "Update watermark called with " +
      "route_id: " + route_id.string() +
      "\tseq_id: " + seq_id.string() + "\n\n").cstring())
    end

    _acker().ack_received(this, route_id, seq_id)
