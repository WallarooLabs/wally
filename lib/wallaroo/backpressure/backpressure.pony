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
use "wallaroo/tcp-source"
use "wallaroo/topology"

trait tag CreditFlowConsumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer, credits_returned: ISize)
  be credit_request(from: Producer)
  be return_credits(credits: ISize)

type CreditFlowProducerConsumer is (Producer & CreditFlowConsumer)

type Consumer is CreditFlowConsumer

trait RouteCallbackHandler
  fun ref register(producer: Producer ref, r: Route tag)
  fun shutdown(p: Producer ref)
  fun ref credits_initialized(producer: Producer ref, r: Route tag)
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
  fun ref application_created()
  fun ref application_initialized(new_max_credits: ISize, step_type: String)
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

  fun ref application_created() =>
    None

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    None

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

interface CreditReceiver
  fun ref receive_credits(credits: ISize)

class EmptyCreditReceiver
  fun ref receive_credits(credits: ISize) =>
    Fail()

class TypedRoutePreparingToWorkCreditReceiver[In: Any val]
  let _route: TypedRoute[In]

  new create(tr: TypedRoute[In]) =>
    _route = tr

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(_route.queue_size() == 0)
      Invariant(_route.credits_available() == 0)
    end

    _route._close_outstanding_request()

    if credits > 0 then
      _route._credits_initialized()

      let credits_recouped =
        if (_route.credits_available() + credits) > _route.max_credits() then
          _route.max_credits() - _route.credits_available()
        else
          credits
        end
      _route._recoup_credits(credits_recouped)

      ifdef "credit_trace" then
        @printf[I32]("--Route (Prep): rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n".cstring(),
          credits, _route.credits_available() - credits,
          _route.max_credits(), _route.queue_size())
      end

      _route._update_request_more_credits_after(_route.credits_available() -
        (_route.credits_available() >> 2))
      _route._report_ready_to_work()
    else
      _route.request_credits()
    end

class TypedRouteWorkingCreditReceiver[In: Any val]
  let _route: TypedRoute[In]
  let _step_type: String

  new create(tr: TypedRoute[In], step_type: String) =>
    _route = tr
    _step_type = step_type

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits >= 0)
    end

    _route._close_outstanding_request()
    let credits_recouped =
      if (_route.credits_available() + credits) > _route.max_credits() then
        _route.max_credits() - _route.credits_available()
      else
        credits
      end
    _route._recoup_credits(credits_recouped)
    if credits > credits_recouped then
      _route._return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32]("--Route (%s): rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n".cstring(),
        _step_type.cstring(), credits, _route.credits_available() - credits,
        _route.max_credits(), _route.queue_size())
    end

    if _route.credits_available() > 0 then
      if (_route.credits_available() - credits_recouped) == 0 then
        _route._credits_replenished()
      end

      if (_route.queue_size() > 0) then
        _route._flush_queue()

        if _route.credits_available() == 0 then
          _route._credits_exhausted()
        end
      end

      _route._update_request_more_credits_after(_route.credits_available() -
        (_route.credits_available() >> 2))
    else
      _route.request_credits()
    end

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  var _step_type: String = ""
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumerStep
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false

  var _credit_receiver: CreditReceiver = EmptyCreditReceiver

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

    // We start at 0 size.  We need to know the max_credits before we
    // can size this in the initialize method.
    _queue = FixedQueue[(String, U64, In, Producer ref, Producer, U128,
      None, SeqId, RouteId)](0)

    _credit_receiver = TypedRoutePreparingToWorkCreditReceiver[In](this)

  fun ref application_created() =>
    _callback.register(_step, this)
    _consumer.register_producer(_step)

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type
    ifdef "backpressure" then
      ifdef debug then
        Invariant(new_max_credits > 0)

        Invariant(new_max_credits ==
          (new_max_credits.usize() - 1).next_pow2().isize())
      end
      _max_credits = new_max_credits
      // Overwrite the old (placeholder) queue with one the correct size.
      _queue = FixedQueue[(String, U64, In, Producer ref, Producer, U128,
        None, SeqId, RouteId)](_max_credits.usize())

      request_credits()
    end

  fun ref update_max_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits > 0)

      Invariant(credits ==
        (credits.usize() - 1).next_pow2().isize())
    end
    _max_credits = credits

  fun id(): U64 =>
    _route_id

  fun credits_available(): ISize =>
    _credits_available

  fun max_credits(): ISize =>
    _max_credits

  fun queue_size(): USize =>
    _queue.size()

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)
    //TODO: Will this gum up the works?
    _hard_flush()

  fun ref _report_ready_to_work() =>
    _credit_receiver = TypedRouteWorkingCreditReceiver[In](this, _step_type)
    match _step
    | let s: Step ref =>
      s.report_route_ready_to_work(this)
    end

  fun ref receive_credits(credits: ISize) =>
    _credit_receiver.receive_credits(credits)

  fun ref _credits_initialized() =>
    _callback.credits_initialized(_step, this)

  fun ref _recoup_credits(credits: ISize) =>
    _credits_available = _credits_available + credits
    _step.recoup_credits(credits)

  fun ref _return_credits(credits: ISize) =>
    _consumer.return_credits(credits)

  fun ref _credits_exhausted() =>
    _callback.credits_exhausted(_step)
    request_credits()

  fun ref _credits_replenished() =>
    _callback.credits_replenished(_step)

  fun ref _update_request_more_credits_after(credits: ISize) =>
    _request_more_credits_after = credits

  fun ref request_credits() =>
    if not _request_outstanding then
      ifdef "credit_trace" then
        @printf[I32]("--Route (%s): requesting credits. Have %llu\n".cstring(),
          _step_type.cstring(), _credits_available)
      end
      _consumer.credit_request(_step)
      _request_outstanding = true
    else
      ifdef "credit_trace" then
        @printf[I32]("----Route (%s): Request already outstanding\n".cstring(),
          _step_type.cstring())
      end
    end

  fun ref _close_outstanding_request() =>
    _request_outstanding = false

  fun ref run[D](metric_name: String, source_ts: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("--Rcvd msg at Route (%s)\n".cstring(),
        _step_type.cstring())
    end
    match data
    | let input: In =>
      ifdef "backpressure" then
        if _credits_available > 0 then
          ifdef debug then
            match _step
            | let source: TCPSource ref =>
              Invariant(not source.is_muted())
            end
          end

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
            _credits_exhausted()
          else
            if above_request_point then
              if _credits_available < _request_more_credits_after then
                // we started above the request size and finished below,
                // request credits
                request_credits()
              end
            end
          end
          ifdef debug then
            Invariant(_queue.size() < _queue.max_size())
          end
          true
        else
          ifdef "trace" then
            @printf[I32]("----No credits: added msg to Route queue (%s)\n".cstring(), _step_type.cstring())
          end
          _add_to_queue(metric_name, source_ts, input, cfp,
            origin, msg_uid, frac_ids, i_seq_id, i_route_id)
          not (_queue.size() == _queue.max_size())
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
      @printf[I32]("Sent msg from Route (%s)\n".cstring(),
        _step_type.cstring())
    end

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1


  fun ref _add_to_queue(metric_name: String, source_ts: U64, input: In,
    cfp: Producer ref, origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    ifdef debug then
      Invariant((_queue.max_size() > 0) and
        (_queue.size() < _queue.max_size()))
    end

    try
      _queue.enqueue((metric_name, source_ts, input, cfp,
        origin, msg_uid, frac_ids, i_seq_id, i_route_id))
      if _queue.size() == _queue.max_size() then
        ifdef "credit_trace" then
          @printf[I32]("Route queue is full (%s).\n".cstring(),
            _step_type.cstring())
        end
      end
    else
      ifdef debug then
        @printf[I32]("Failure trying to enqueue typed route data\n".cstring())
      end
      Fail()
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

class BoundaryRoutePreparingToWorkCreditReceiver
  let _route: BoundaryRoute

  new create(br: BoundaryRoute) =>
    _route = br

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(_route.queue_size() == 0)
      Invariant(_route.credits_available() == 0)
    end

    _route._close_outstanding_request()

    if credits > 0 then
      _route._credits_initialized()

      let credits_recouped =
        if (_route.credits_available() + credits) > _route.max_credits() then
          _route.max_credits() - _route.credits_available()
        else
          credits
        end
      _route._recoup_credits(credits_recouped)

      ifdef "credit_trace" then
        @printf[I32]("--BoundaryRoute: rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n".cstring(),
          credits, _route.credits_available() - credits,
          _route.max_credits(), _route.queue_size())
      end

      _route._update_request_more_credits_after(_route.credits_available() -
        (_route.credits_available() >> 2))
      _route._report_ready_to_work()
    else
      _route.request_credits()
    end

class BoundaryRouteWorkingCreditReceiver
  let _route: BoundaryRoute
  let _step_type: String

  new create(tr: BoundaryRoute, step_type: String) =>
    _route = tr
    _step_type = step_type

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits >= 0)
    end

    _route._close_outstanding_request()
    let credits_recouped =
      if (_route.credits_available() + credits) > _route.max_credits() then
        _route.max_credits() - _route.credits_available()
      else
        credits
      end
    _route._recoup_credits(credits_recouped)
    if credits > credits_recouped then
      _route._return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32]("--BoundaryRoute (%s): rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n".cstring(),
        _step_type.cstring(), credits, _route.credits_available() - credits,
        _route.max_credits(), _route.queue_size())
    end

    if _route.credits_available() > 0 then
      if (_route.credits_available() - credits_recouped) == 0 then
        _route._credits_replenished()
      end

      if (_route.queue_size() > 0) then
        _route._flush_queue()

        if _route.credits_available() == 0 then
          _route._credits_exhausted()
        end
      end

      _route._update_request_more_credits_after(_route.credits_available() -
        (_route.credits_available() >> 2))
    else
      _route.request_credits()
    end

class BoundaryRoute is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  let _step: Producer ref
  var _step_type: String = ""
  let _callback: RouteCallbackHandler
  let _consumer: OutgoingBoundary
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false

  var _credit_receiver: CreditReceiver = EmptyCreditReceiver

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
    _queue = FixedQueue[(ReplayableDeliveryMsg val, Producer ref,
      Producer, U128, None, SeqId, RouteId)](0)
    _credit_receiver = BoundaryRoutePreparingToWorkCreditReceiver(this)

  fun ref application_created() =>
    _callback.register(_step, this)
    _consumer.register_producer(_step)

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type
    ifdef "backpressure" then
      ifdef debug then
        Invariant(new_max_credits ==
          (new_max_credits.usize() - 1).next_pow2().isize())
      end
      ifdef debug then
        Invariant(new_max_credits > 0)
      end
      _max_credits = new_max_credits
      // Overwrite the old (placeholder) queue with one the correct size.
      _queue = FixedQueue[(ReplayableDeliveryMsg val, Producer ref,
        Producer, U128, None, SeqId, RouteId)](_max_credits.usize())

      request_credits()
    end

  fun ref update_max_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits ==
        (credits.usize() - 1).next_pow2().isize())
    end
    ifdef debug then
      Invariant(credits > 0)
    end
    _max_credits = credits

  fun id(): U64 =>
    _route_id

  fun credits_available(): ISize =>
    _credits_available

  fun max_credits(): ISize =>
    _max_credits

  fun queue_size(): USize =>
    _queue.size()

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)
    //TODO: Will this gum up the works?
    _hard_flush()

  fun ref _report_ready_to_work() =>
    _credit_receiver = BoundaryRouteWorkingCreditReceiver(this, _step_type)
    match _step
    | let s: Step ref =>
      s.report_route_ready_to_work(this)
    end

  fun ref receive_credits(credits: ISize) =>
    _credit_receiver.receive_credits(credits)

  fun ref _credits_initialized() =>
    _callback.credits_initialized(_step, this)

  fun ref _recoup_credits(credits: ISize) =>
    _credits_available = _credits_available + credits
    _step.recoup_credits(credits)

  fun ref _return_credits(credits: ISize) =>
    _consumer.return_credits(credits)

  fun ref _credits_exhausted() =>
    _callback.credits_exhausted(_step)
    request_credits()

  fun ref _credits_replenished() =>
    _callback.credits_replenished(_step)

  fun ref _update_request_more_credits_after(credits: ISize) =>
    _request_more_credits_after = credits

  fun ref request_credits() =>
    if not _request_outstanding then
      ifdef "credit_trace" then
        @printf[I32]("--BoundaryRoute (%s): requesting credits. Have %llu\n".cstring(), _step_type.cstring(), _credits_available)
      end
      _consumer.credit_request(_step)
      _request_outstanding = true
    else
      ifdef "credit_trace" then
        @printf[I32]("----BoundaryRoute (%s): Request already outstanding\n".cstring(), _step_type.cstring())
      end
    end

  fun ref _close_outstanding_request() =>
    _request_outstanding = false

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
      @printf[I32]("Rcvd msg at BoundaryRoute (%s)\n".cstring(),
        _step_type.cstring())
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
          _credits_exhausted()
        else
          if above_request_point then
            if _credits_available < _request_more_credits_after then
              // we started above the request size and finished below,
              // request credits
              request_credits()
            end
          end
        end
        ifdef debug then
          Invariant(_queue.size() < _queue.max_size())
        end
        true
      else
        _add_to_queue(delivery_msg,
          cfp,
          i_origin,
          msg_uid,
          i_frac_ids,
          i_seq_id,
          i_route_id)
        not (_queue.size() == _queue.max_size())
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
    i_seq_id: SeqId, i_route_id: RouteId)
  =>
    ifdef debug then
      Invariant((_queue.max_size() > 0) and
        (_queue.size() < _queue.max_size()))
    end

    try
      _queue.enqueue((delivery_msg, cfp,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id))

      if _queue.size() == _queue.max_size() then
        ifdef "credit_trace" then
          @printf[I32]("Boundary route queue is full (%s).\n".cstring(),
            _step_type.cstring())
        end
      end
    else
      ifdef debug then
        @printf[I32]("Failure trying to enqueue boundary route data\n".cstring())
      end
      Fail()
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
