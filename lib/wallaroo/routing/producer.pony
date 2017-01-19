trait tag Producer
  // from CreditFlowProducer
  be receive_credits(credits: ISize, from: CreditFlowConsumer)
  be mute(c: CreditFlowConsumer)
  be unmute(c: CreditFlowConsumer)
  fun ref recoup_credits(credits: ISize)
  fun ref route_to(c: CreditFlowConsumer): (Route | None)
  fun ref next_sequence_id(): U64

  // from Origin
  fun tag hash(): U64 =>
    (digestof this).hash()

  fun ref _x_resilience_routes(): Routes

  fun ref _flush(low_watermark: SeqId)

  be log_flushed(low_watermark: SeqId) =>
    """
    We will be called back here once the eventlogs have been flushed for a
    particular origin. We can now send the low watermark upstream to this
    origin.
    """

    _x_resilience_routes().flushed(low_watermark)

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
      _x_resilience_routes().send(this, o_route_id, o_seq_id,
        i_origin, i_route_id, i_seq_id)
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

    _x_resilience_routes().receive_ack(this, route_id, seq_id)

primitive HashProducer
  fun hash(o: Producer): U64 =>
    o.hash()

  fun eq(o1: Producer, o2: Producer): Bool =>
    o1.hash() == o2.hash()

  fun ne(o1: Producer, o2: Producer): Bool =>
    o1.hash() != o2.hash()
