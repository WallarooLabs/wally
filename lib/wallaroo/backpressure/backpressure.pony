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
  // TODO: CREDITFLOW - None is a placeholder
  fun ref route_to(c: CreditFlowConsumerStep): (Route | None)

type CreditFlowProducerConsumer is (CreditFlowProducer & CreditFlowConsumer)

trait RouteCallbackHandler
  fun shutdown(p: CreditFlowProducer ref)
  fun credits_replenished(p: CreditFlowProducer ref)
  fun credits_exhausted(p: CreditFlowProducer ref)

class Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = GuidGenerator.u64()
  let _step: CreditFlowProducer ref
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumer
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  var _seq_id: U64 = 0
  // TODO: CREDIT-FLOW: Change to generic type for data
  // aka 3rd tuple field
  embed _queue: Array[(String, U64, U64, U128, (Array[U64] val | None))]
    = _queue.create()

  new create(step: CreditFlowProducer ref, consumer: CreditFlowConsumer,
    handler: RouteCallbackHandler)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _consumer.register_producer(_step)

  fun ref initialize() =>
    _request_credits()

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref receive_credits(credits: ISize) =>
     ifdef debug then
      try
        Assert(credits >= 0,
        "Producer received credits negative credits")
      else
        _callback.shutdown(_step)
        return
      end
    end

    _request_outstanding = false
    _credits_available = _credits_available + credits

    if _credits_available > 0 then
      if (_credits_available - credits) == 0 then
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

  // TODO: CREDITFLOW- Make generic
  fun ref run(metric_name: String, source_ts: U64, data: U64,
    msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    if _credits_available > 0 then
      let above_request_point =
        _credits_available >= _request_more_credits_after

      if _queue.size() > 0 then
        _add_to_queue(metric_name, source_ts, data, msg_uid, frac_ids)
        _flush_queue()
      else
        _send_message_on_route(metric_name, source_ts, data, msg_uid, frac_ids)
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
      _add_to_queue(metric_name, source_ts, data, msg_uid, frac_ids)
      _request_credits()
    end

  // TODO: CREDITFLOW- Make generic
  // TODO: CREDITFLOW- uncomment real implementation
  fun ref _send_message_on_route(metric_name: String, source_ts: U64,
    data: U64, msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    /*
    _consumer.run[D](metric_name,
      source_ts,
      data,
      _step,
      msg_uid,
      frac_ids,
      _next_sequence_id(),
      _route_id)
      */

      _credits_available = _credits_available - 1

  fun ref _next_sequence_id(): U64 =>
    _seq_id = _seq_id + 1

  fun ref _add_to_queue(metric_name: String, source_ts: U64,
    data: U64, msg_uid: U128, frac_ids: (Array[U64] val | None))
  =>
    _queue.push((metric_name, source_ts, data, msg_uid, frac_ids))

  fun ref _flush_queue() =>
    while ((_credits_available > 0) and (_queue.size() > 0)) do
      try
        let d =_queue.shift()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5)
      end
    end
