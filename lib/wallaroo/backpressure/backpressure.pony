use "assert"
use "sendence/guid"
use "wallaroo/messages"
use "wallaroo/topology"

trait tag CreditFlowConsumer
  be register_producer(producer: CreditFlowProducer)
  be unregister_producer(producer: CreditFlowProducer, credits_returned: ISize)
  be credit_request(from: CreditFlowProducer)

trait tag CreditFlowProducer
  be receive_credits(credits: ISize, from: CreditFlowConsumer)
  fun ref route_to(c: CreditFlowConsumerStep): (Route | None)

type CreditFlowProducerConsumer is (CreditFlowProducer & CreditFlowConsumer)

trait val RouteCallbackHandler
  fun shutdown(p: CreditFlowProducer ref)
  fun credits_replenished(p: CreditFlowProducer ref)
  fun credits_exhausted(p: CreditFlowProducer ref)

trait RouteBuilder
  fun apply(step: CreditFlowProducer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: CreditFlowProducer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route 
  =>
    TypedRoute[In](step, consumer, handler)

primitive EmptyRouteBuilder is RouteBuilder
  fun apply(step: CreditFlowProducer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler): Route
  =>
    EmptyRoute  

trait Route
  fun ref initialize()
  fun credits(): ISize
  fun ref dispose()
  fun ref receive_credits(number: ISize)
  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    msg_uid: U128, frac_ids: (Array[U64] val | None))

class EmptyRoute is Route
  fun ref initialize() => None
  fun credits(): ISize => 0
  fun ref dispose() => None
  fun ref receive_credits(number: ISize) => None
  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    msg_uid: U128, frac_ids: (Array[U64] val | None))
  => 
    None

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = GuidGenerator.u64()
  let _step: CreditFlowProducer ref
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumerStep
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  var _seq_id: U64 = 0
  embed _queue: Array[(String, U64, In, U128, (Array[U64] val | None))]
    = _queue.create()

  new create(step: CreditFlowProducer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)
    _credits_available = 
      ifdef "use_backpressure" then
        0
      else
        100000000000
      end

  fun ref initialize() =>
    ifdef "use_backpressure" then
      _request_credits()
    else
      None
    end

  fun credits(): ISize => _credits_available

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref receive_credits(number: ISize) =>
     ifdef debug then
      try
        Assert(number > 0,
        "Producer received credits negative credits")
      else
        _callback.shutdown(_step)
        return
      end
    end

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
    msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    match data
    | let input: In =>
      if _credits_available > 0 then
        let above_request_point =
          _credits_available >= _request_more_credits_after

        if _queue.size() > 0 then
          _add_to_queue(metric_name, source_ts, input, msg_uid, frac_ids)
          _flush_queue()
        else
          _send_message_on_route(metric_name, source_ts, input, msg_uid, 
            frac_ids)
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
        _add_to_queue(metric_name, source_ts, input, msg_uid, frac_ids)
        _request_credits()
      end
    end

  fun ref _send_message_on_route(metric_name: String, source_ts: U64,
    input: In, msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    _consumer.run[In](metric_name,
      source_ts,
      input,  
      // TODO: This should be _step but we need to fix type since it has
      // to implement Origin tag
      None,
      msg_uid,
      frac_ids,
      _next_sequence_id(),
      _route_id)
     
      _credits_available = _credits_available - 1

  fun ref _next_sequence_id(): U64 =>
    _seq_id = _seq_id + 1

  fun ref _add_to_queue(metric_name: String, source_ts: U64,
    input: In, msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    _queue.push((metric_name, source_ts, input, msg_uid, frac_ids))

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.shift()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5)
      end
    end
