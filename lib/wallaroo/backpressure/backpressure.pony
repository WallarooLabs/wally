use "assert"
use "time"
use "sendence/guid"
use "sendence/container-queue"
use "sendence/fixed-queue"
use "sendence/queue"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/tcp-sink"
use "wallaroo/topology"

trait tag CreditFlowConsumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer, credits_returned: ISize)
  be credit_request(from: Producer, credits_requested: ISize)
  be return_credits(credits: ISize)

type CreditFlowProducerConsumer is (Producer & CreditFlowConsumer)

type Consumer is CreditFlowConsumer

trait RouteCallbackHandler
  fun shutdown(p: Producer ref)
  fun ref credits_replenished(p: Producer ref)
  fun ref credits_exhausted(p: Producer ref)

trait RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, handler)
    else
      TypedRoute[In](step, consumer, handler)
    end

primitive EmptyRouteBuilder is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route
  =>
    EmptyRoute

trait Route
  fun ref initialize(max_credits: ISize)
  fun ref update_max_credits(max_credits: ISize)
  fun id(): U64
  fun credits_available(): ISize
  fun ref dispose()
  fun ref request_credits()
  fun ref receive_credits(number: ISize)
  // Return false to indicate queue is full and if producer is a Source, it
  // should mute
  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId): Bool


class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages

  fun ref initialize(max_credits: ISize) => None
  fun id(): U64 => _route_id
  fun ref update_max_credits(max_credits: ISize) => None
  fun credits_available(): ISize => 0
  fun ref dispose() => None
  fun ref request_credits() => None
  fun ref receive_credits(number: ISize) => None

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId): Bool
  =>
    true

type TypedRouteQueueTuple[D: Any val] is (String, U64, D, Producer ref,
  Producer, U128, None, SeqId, RouteId)

class TypedRouteQueueData[D: Any val]
  var metric_name: String
  var source_ts: U64
  var data: D
  var producer: Producer ref
  var origin: Producer
  var msg_uid: U128
  var frac_ids: None
  var i_seq_id: SeqId
  var i_route_id: RouteId

  new create(t: TypedRouteQueueTuple[D]) =>
    metric_name = t._1
    source_ts = t._2
    data = t._3
    producer = t._4
    origin = t._5
    msg_uid = t._6
    frac_ids = t._7
    i_seq_id = t._8
    i_route_id = t._9

  fun ref write(t: TypedRouteQueueTuple[D]) =>
    metric_name = t._1
    source_ts = t._2
    data = t._3
    producer = t._4
    origin = t._5
    msg_uid = t._6
    frac_ids = t._7
    i_seq_id = t._8
    i_route_id = t._9

  fun ref read(): TypedRouteQueueTuple[D] =>
    (metric_name, source_ts, data, producer, origin, msg_uid, frac_ids,
      i_seq_id, i_route_id)

class TypedRouteQueueDataBuilder[D: Any val]
  fun apply(t: TypedRouteQueueTuple[D]): TypedRouteQueueData[D]
  =>
    TypedRouteQueueData[D](t)

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumerStep
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  var _last_credit_ts: U64 = 0 // Timestamp we last requested


  // _queue stores tuples of the form:
  // (metric_name: String, source_ts: U64, data: D,
  //  cfp: Producer ref,
  //  origin: Producer, msg_uid: U128,
  //  frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  var _queue: FixedQueue[(String, U64, In, Producer ref, Producer, U128,
    None, SeqId, RouteId)]
  // let _queue: ContainerQueue[TypedRouteQueueTuple[In], TypedRouteQueueData[In]]

  new create(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)
    ifdef "backpressure" then
      handler.credits_exhausted(_step)
    end
    // let q_size: USize = ifdef "backpressure" then
    //   500_000
    // else
    //   0
    // end

    // We start at 0 size.  We need to know the max_credits before we
    // can size this in the initialize method.
    _queue = FixedQueue[(String, U64, In, Producer ref, Producer, U128,
      None, SeqId, RouteId)](0)
    // _queue = ContainerQueue[TypedRouteQueueTuple[In], TypedRouteQueueData[In]](
    //   TypedRouteQueueDataBuilder[In], q_size)

  fun ref initialize(max_credits: ISize) =>
    ifdef "backpressure" then
      ifdef debug then
        try
          Assert(max_credits > 0,
            "Route max credits must be greater than 0")
        else
          _callback.shutdown(_step)
          return
        end
      end

      _max_credits = max_credits
      // Overwrite the old (placeholder) queue with one the correct size.
      _queue = FixedQueue[(String, U64, In, Producer ref, Producer, U128,
        None, SeqId, RouteId)](_max_credits.usize())
      request_credits()
    end

  fun ref update_max_credits(max_credits: ISize) =>
    ifdef debug then
      try
        Assert(max_credits > 0,
          "Route max credits must be greater than 0")
      else
        _callback.shutdown(_step)
        return
      end
    end
    _max_credits = max_credits

  fun id(): U64 =>
    _route_id

  fun credits_available(): ISize =>
    _credits_available

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)
    //TODO: Will this gum up the works?
    _hard_flush()

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits >= 0)
    end

    _request_outstanding = false
    let credits_recouped =
      if (_credits_available + number) > _max_credits then
        _max_credits - _credits_available
      else
        number
      end
    _credits_available = _credits_available + credits_recouped
    _step.recoup_credits(credits_recouped)
    _consumer.ack_credits(number, number - credits_recouped)

    ifdef "credit_trace" then
      @printf[I32]("--Route: rcvd %llu credits. Used %llu. Had %llu out of %llu\n".cstring(), number, credits_recouped,
        _credits_available - credits_recouped, _max_credits)
    end

    if _credits_available > 0 then
      if (_credits_available - credits) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _callback.credits_exhausted(_step)
          request_credits()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      request_credits()
    end

  fun ref request_credits() =>
    if not _request_outstanding then
      ifdef "credit_trace" then
        @printf[I32]("--Route: requesting credits\n".cstring())
      end
      let credits_requested = _max_credits - _credits_available
      _consumer.credit_request(_step, credits_requested)
      _last_credit_ts = Time.nanos()
      _request_outstanding = true
    else
      ifdef "credit_trace" then
        @printf[I32]("----Request already outstanding\n".cstring())
      end
    end

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("--Rcvd msg at Route\n".cstring())
    end
    match data
    | let input: In =>
      ifdef "backpressure" then
        if _credits_available > 0 then
          let above_request_point =
            _credits_available >= _request_more_credits_after

          if _queue.size() > 0 then
            _add_to_queue(metric_name, source_ts, input, cfp, origin, msg_uid,
              frac_ids, i_seq_id, i_route_id)
            _flush_queue()
          else
            _send_message_on_route(metric_name, source_ts, input, cfp, origin,
              msg_uid, frac_ids, i_seq_id, i_route_id)
          end

          if _credits_available == 0 then
            _callback.credits_exhausted(_step)
            request_credits()
          else
            if above_request_point then
              if _credits_available < _request_more_credits_after then
                // we started above the request size and finished below,
                // request credits
                request_credits()
              end
            end
          end
          true
        else
          ifdef "trace" then
            @printf[I32]("----No credits: added msg to Route queue\n".cstring())
          end
          let keep_sending = _add_to_queue(metric_name, source_ts, input, cfp, 
            origin, msg_uid, frac_ids, i_seq_id, i_route_id)
          request_credits()
          keep_sending
        end
      else
        _send_message_on_route(metric_name, source_ts, input, cfp, origin,
          msg_uid, frac_ids, i_seq_id, i_route_id)
        true
      end
    else
      Fail()
      true
    end

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId): Bool
  =>
    // Forward should never be called on a TypedRoute
    Fail()
    true

  fun ref _send_message_on_route(metric_name: String, source_ts: U64, input: In,
    cfp: Producer ref, i_origin: Producer, msg_uid: U128, frac_ids: None,
    i_seq_id: SeqId, i_route_id: RouteId)
  =>
    let o_seq_id = cfp.next_sequence_id()

    _consumer.run[In](metric_name,
      source_ts,
      input,
      cfp,
      msg_uid,
      frac_ids,
      o_seq_id,
      _route_id)

    ifdef "trace" then
      @printf[I32]("Sent msg from Route\n".cstring())
    end

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1


  fun ref _add_to_queue(metric_name: String, source_ts: U64, input: In,
    cfp: Producer ref, origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef debug then
      Invariant(_queue.size() < _queue.max_size())
    end

    try
      _queue.enqueue((metric_name, source_ts, input, cfp,
        origin, msg_uid, frac_ids, i_seq_id, i_route_id))
      if _queue.size() == _queue.max_size() then
        ifdef "credit_trace" then
          @printf[I32]("Route queue is full.\n".cstring())
        end
        @printf[I32]("!!Route queue is full.\n".cstring())
        false
      else
        true
      end
    else
      ifdef debug then
        @printf[I32]("Failure trying to enqueue typed route data\n".cstring())
      end
      Fail()
      true
    end

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6,
          d._7, d._8, d._9)
      end
    end

  fun ref _hard_flush() =>
    while (_queue.size() > 0) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6,
          d._7, d._8, d._9)
      end
    end

type BoundaryRouteQueueTuple is (ReplayableDeliveryMsg val, Producer ref,
  Producer, U128, None, SeqId)

class BoundaryRouteQueueData
  var delivery_msg: ReplayableDeliveryMsg val
  var producer: Producer ref
  var i_origin: Producer
  var msg_uid: U128
  var i_frac_ids: None
  var i_seq_id: SeqId

  new create(t: BoundaryRouteQueueTuple) =>
    delivery_msg = t._1
    producer = t._2
    i_origin = t._3
    msg_uid = t._4
    i_frac_ids = t._5
    i_seq_id = t._6

  fun ref write(t: BoundaryRouteQueueTuple) =>
    delivery_msg = t._1
    producer = t._2
    i_origin = t._3
    msg_uid = t._4
    i_frac_ids = t._5
    i_seq_id = t._6

  fun ref read(): BoundaryRouteQueueTuple =>
    (delivery_msg, producer, i_origin, msg_uid, i_frac_ids, i_seq_id)

class BoundaryRouteQueueDataBuilder
  fun apply(t: BoundaryRouteQueueTuple): BoundaryRouteQueueData
  =>
    BoundaryRouteQueueData(t)

class BoundaryRoute is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  let _callback: RouteCallbackHandler
  let _consumer: OutgoingBoundary
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  var _last_credit_ts: U64 = 0 // Timestamp we last requested

  // Store tuples of the form
  // (delivery_msg, cfp, i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
  var _queue: FixedQueue[(ReplayableDeliveryMsg val, Producer ref,
    Producer, U128, None, SeqId, RouteId)]

  new create(step: Producer ref, consumer: OutgoingBoundary,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)
    ifdef "backpressure" then
      handler.credits_exhausted(_step)
    end
    _queue = FixedQueue[(ReplayableDeliveryMsg val, Producer ref,
      Producer, U128, None, SeqId, RouteId)](0)

  fun ref initialize(max_credits: ISize) =>
    ifdef "backpressure" then
      _max_credits = max_credits
      // Overwrite the old (placeholder) queue with one the correct size.
      _queue = FixedQueue[(ReplayableDeliveryMsg val, Producer ref,
        Producer, U128, None, SeqId, RouteId)](max_credits.usize())
      request_credits()
    end

  fun ref update_max_credits(max_credits: ISize) =>
    _max_credits = max_credits

  fun id(): U64 =>
    _route_id

  fun credits_available(): ISize =>
    _credits_available

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)
    //TODO: Will this gum up the works?
    _hard_flush()

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits >= 0)
    end

    _request_outstanding = false
    let credits_recouped =
      if (_credits_available + number) > _max_credits then
        _max_credits - _credits_available
      else
        number
      end
    _credits_available = _credits_available + credits_recouped
    _step.recoup_credits(credits_recouped)
    _consumer.return_credits(credits - credits_recouped)

    if _credits_available > 0 then
      if (_credits_available - credits) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _callback.credits_exhausted(_step)
          request_credits()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      request_credits()
    end

  fun ref request_credits() =>
    if (Time.nanos() - _last_credit_ts) > 1_000_000_000 then
      if not _request_outstanding then
        ifdef "credit_trace" then
          @printf[I32]("--BoundaryRoute: requesting credits\n".cstring())
        end
        let requested_credits = _max_credits - _credits_available
        _consumer.credit_request(_step, requested_credits)
        _last_credit_ts = Time.nanos()
        _request_outstanding = true
      else
        ifdef "credit_trace" then
          @printf[I32]("----Request already outstanding\n".cstring())
        end
      end
    end

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    // Run should never be called on a BoundaryRoute
    Fail()
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at BoundaryRoute\n".cstring())
    end
    ifdef "backpressure" then
      if _credits_available > 0 then
        let above_request_point =
          _credits_available >= _request_more_credits_after

        if _queue.size() > 0 then
          _add_to_queue(delivery_msg,
            cfp,
            i_origin,
            msg_uid,
            i_frac_ids,
            i_seq_id,
            i_route_id)
          _flush_queue()
        else
          _send_message_on_route(delivery_msg,
            cfp,
            i_origin,
            msg_uid,
            i_frac_ids,
            i_seq_id,
            _route_id)
        end

        if _credits_available == 0 then
          _callback.credits_exhausted(_step)
          request_credits()
        else
          if above_request_point then
            if _credits_available < _request_more_credits_after then
              // we started above the request size and finished below,
              // request credits
              request_credits()
            end
          end
        end
        true
      else
        let keep_sending = _add_to_queue(delivery_msg,
          cfp,
          i_origin,
          msg_uid,
          i_frac_ids,
          i_seq_id,
          i_route_id)
        request_credits()
        keep_sending
      end
    else
      _send_message_on_route(delivery_msg,
        cfp,
        i_origin,
        msg_uid,
        i_frac_ids,
        i_seq_id,
        _route_id)
      true
    end

  fun ref _send_message_on_route(delivery_msg: ReplayableDeliveryMsg val,
    cfp: Producer ref, i_origin: Producer, msg_uid: U128, i_frac_ids: None,
    i_seq_id: SeqId, i_route_id: RouteId)
  =>
    let o_seq_id = cfp.next_sequence_id()

    _consumer.forward(delivery_msg,
      cfp,
      msg_uid,
      i_frac_ids,
      o_seq_id,
      _route_id)

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1

  fun ref _add_to_queue(delivery_msg: ReplayableDeliveryMsg val,
    cfp: Producer ref, i_origin: Producer, msg_uid: U128, i_frac_ids: None,
    i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef debug then
      Invariant(_queue.size() < _queue.max_size())
    end

    try
      _queue.enqueue((delivery_msg, cfp,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id))
      if _queue.size() == _queue.max_size() then
        ifdef "credit_trace" then
          @printf[I32]("Route queue is full.\n".cstring())
        end
        false
      else
        true
      end
    else
      ifdef debug then
        @printf[I32]("Failure trying to enqueue boundary route data\n".cstring())
      end
      Fail()
      true
    end

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6, _route_id)
      end
    end

  fun ref _hard_flush() =>
    while (_queue.size() > 0) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6, _route_id)
      end
    end
