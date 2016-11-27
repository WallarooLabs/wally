use "assert"
use "sendence/guid"
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
  be credit_request(from: Producer)

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
  fun ref initialize()
  fun id(): U64
  fun credits(): ISize
  fun ref dispose()
  fun ref receive_credits(number: ISize)
  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId)


class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages

  fun ref initialize() => None
  fun id(): U64 => _route_id
  fun credits(): ISize => 0
  fun ref dispose() => None
  fun ref receive_credits(number: ISize) => None

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    None

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId)
  =>
    None

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumerStep
  var _credits_available: ISize = 1
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false

  // _queue stores tuples of the form:
  // (metric_name: String, source_ts: U64, data: D,
  //  cfp: Producer ref,
  //  origin: Producer, msg_uid: U128,
  //  frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  let _queue: Array[(String, U64, In, Producer ref, Producer, U128,
    None, SeqId, RouteId)]

  new create(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)
    let q_size: USize = ifdef "use_backpressure" then
      500_000
    else
      0
    end
    _queue = Array[(String, U64, In, Producer ref, Producer, U128,
      None, SeqId, RouteId)](q_size)

  fun ref initialize() =>
    None

  fun id(): U64 =>
    _route_id

  fun credits(): ISize =>
    _credits_available

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref receive_credits(number: ISize) =>
    Invariant(number > 0)

    _request_outstanding = false
    _credits_available = _credits_available + number

    if _credits_available > 0 then
      if (_credits_available - number) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _callback.credits_exhausted(_step)
          _request_credits()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      _request_credits()
    end

  fun ref _request_credits() =>
    if not _request_outstanding then
      _consumer.credit_request(_step)
      _request_outstanding = true
    end

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at Route\n".cstring())
    end
    match data
    | let input: In =>
      ifdef "use_backpressure" then
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
            _request_credits()
          else
            if above_request_point then
              if _credits_available < _request_more_credits_after then
                // we started above the request size and finished below,
                // request credits
                _request_credits()
              end
            end
          end
        else
          _add_to_queue(metric_name, source_ts, input, cfp, origin, msg_uid,
            frac_ids, i_seq_id, i_route_id)
          _request_credits()
        end
      else
        _send_message_on_route(metric_name, source_ts, input, cfp, origin,
          msg_uid, frac_ids, i_seq_id, i_route_id)
      end
    else
      Fail()
    end

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId)
  =>
    // Forward should never be called on a TypedRoute
    Fail()

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

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1


  fun ref _add_to_queue(metric_name: String, source_ts: U64, input: In,
    cfp: Producer ref, origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    _queue.push((metric_name, source_ts, input, cfp,
      origin, msg_uid, frac_ids, i_seq_id, i_route_id))

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.shift()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6,
          d._7, d._8, d._9)
      end
    end

class BoundaryRoute is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  let _callback: RouteCallbackHandler
  let _consumer: OutgoingBoundary
  var _credits_available: ISize = 1
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  // Store tuples of the form
  // (delivery_msg, cfp, i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
  let _queue: Array[(ReplayableDeliveryMsg val, Producer ref,
    Producer, U128, None, SeqId, RouteId)]

  new create(step: Producer ref, consumer: OutgoingBoundary,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)
    let q_size: USize = ifdef "use_backpressure" then
      500_000
    else
      0
    end
    _queue = Array[(ReplayableDeliveryMsg val, Producer ref,
      Producer, U128, None, SeqId, RouteId)](q_size)

  fun ref initialize() =>
    None

  fun id(): U64 =>
    _route_id

  fun credits(): ISize =>
    _credits_available

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref receive_credits(number: ISize) =>
     Invariant(number > 0)

    _request_outstanding = false
    _credits_available = _credits_available + number

    if _credits_available > 0 then
      if (_credits_available - number) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _callback.credits_exhausted(_step)
          _request_credits()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      _request_credits()
    end

  fun ref _request_credits() =>
    if not _request_outstanding then
      _consumer.credit_request(_step)
      _request_outstanding = true
    end

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    // Run should never be called on a BoundaryRoute
    Fail()

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at BoundaryRoute\n".cstring())
    end
    ifdef "use_backpressure" then
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
            _route_id)
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
          _request_credits()
        else
          if above_request_point then
            if _credits_available < _request_more_credits_after then
              // we started above the request size and finished below,
              // request credits
              _request_credits()
            end
          end
        end
      else
        _add_to_queue(delivery_msg,
          cfp,
          i_origin,
          msg_uid,
          i_frac_ids,
          i_seq_id,
          _route_id)
        _request_credits()
      end
    else
      _send_message_on_route(delivery_msg,
        cfp,
        i_origin,
        msg_uid,
        i_frac_ids,
        i_seq_id,
        _route_id)
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
    i_seq_id: SeqId, i_route_id: RouteId)
  =>
    _queue.push((delivery_msg, cfp,
      i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id))

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.shift()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6, d._7)
      end
    end
