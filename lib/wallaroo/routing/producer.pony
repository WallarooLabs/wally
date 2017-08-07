use "collections"
use "wallaroo/boundary"
use "wallaroo/topology"
use "wallaroo/watermarking"

trait tag Producer
  be mute(c: Consumer)
  be unmute(c: Consumer)
  fun ref route_to(c: Consumer): (Route | None)
  fun ref next_sequence_id(): SeqId
  fun ref current_sequence_id(): SeqId

  // from Origin
  fun tag hash(): U64 =>
    (digestof this).hash()

  //TO DO: one to many. swap in a watermarker here.

  fun ref _x_resilience_routes(): Acker

  // TO DO: temporary one to many change to make this public
  fun ref flush(low_watermark: SeqId)

  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64,
    payload: ByteSeq)
  =>
    None

  be log_flushed(low_watermark: SeqId) =>
    """
    We will be called back here once the eventlogs have been flushed for a
    particular origin. We can now send the low watermark upstream to this
    origin.
    """
    _x_resilience_routes().flushed(low_watermark)

  // TO DO: one to many. cut down method signature
  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    """
    Process envelopes and keep track of things
    """
    ifdef "trace" then
      @printf[I32]("Bookkeeping called for route %llu\n".cstring(), o_route_id)
    end
    ifdef "resilience" then
      _x_resilience_routes().sent(o_route_id, o_seq_id)
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

    _x_resilience_routes().ack_received(this, route_id, seq_id)
