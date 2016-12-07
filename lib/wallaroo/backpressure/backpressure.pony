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
use "wallaroo/metrics"

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
  fun ref credits_replenished(p: Producer ref)
  fun ref credits_exhausted(p: Producer ref)

trait RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, handler, consume metrics_reporter)
    else
      TypedRoute[In](step, consumer, handler, consume metrics_reporter)
    end

primitive EmptyRouteBuilder is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref): Route
  =>
    EmptyRoute

trait Route
  fun ref initialize(max_credits: ISize, step_type: String)
  fun ref update_max_credits(max_credits: ISize)
  fun id(): U64
  fun credits_available(): ISize
  fun ref dispose()
  fun ref request_credits()
  fun ref receive_credits(number: ISize)
  // Return false to indicate queue is full and if producer is a Source, it
  // should mute
  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool


class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages

  fun ref initialize(max_credits: ISize, step_type: String) => None
  fun id(): U64 => _route_id
  fun ref update_max_credits(max_credits: ISize) => None
  fun credits_available(): ISize => 0
  fun ref dispose() => None
  fun ref request_credits() => None
  fun ref receive_credits(number: ISize) => None

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool
  =>
    true

type TypedRouteQueueTuple[D: Any val] is (String, U64, D, Producer ref,
  Producer, U128, None, SeqId, RouteId)

class TypedRouteQueueData[D: Any val]
  var metric_name: String
  var pipeline_time_spent: U64
  var data: D
  var producer: Producer ref
  var origin: Producer
  var msg_uid: U128
  var frac_ids: None
  var i_seq_id: SeqId
  var i_route_id: RouteId

  new create(t: TypedRouteQueueTuple[D]) =>
    metric_name = t._1
    pipeline_time_spent = t._2
    data = t._3
    producer = t._4
    origin = t._5
    msg_uid = t._6
    frac_ids = t._7
    i_seq_id = t._8
    i_route_id = t._9

  fun ref write(t: TypedRouteQueueTuple[D]) =>
    metric_name = t._1
    pipeline_time_spent = t._2
    data = t._3
    producer = t._4
    origin = t._5
    msg_uid = t._6
    frac_ids = t._7
    i_seq_id = t._8
    i_route_id = t._9

  fun ref read(): TypedRouteQueueTuple[D] =>
    (metric_name, pipeline_time_spent, data, producer, origin, msg_uid, frac_ids,
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
  var _step_type: String = ""
  let _callback: RouteCallbackHandler
  let _consumer: CreditFlowConsumerStep
  let _metrics_reporter: MetricsReporter
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false


  // _queue stores tuples of the form:
  // (metric_name: String, pipeline_time_spent: U64, data: D,
  //  cfp: Producer ref,
  //  origin: Producer, msg_uid: U128,
  //  frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
  //  latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  var _queue: FixedQueue[(String, U64, In, Producer ref, Producer, U128,
    None, SeqId, RouteId, U64, U16, U64)]
  // let _queue: ContainerQueue[TypedRouteQueueTuple[In], TypedRouteQueueData[In]]

  new create(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _callback.register(_step, this)
    _metrics_reporter = consume metrics_reporter
    _consumer.register_producer(_step)

    // We start at 0 size.  We need to know the max_credits before we
    // can size this in the initialize method.
    _queue = FixedQueue[(String, U64, In, Producer ref, Producer, U128,
      None, SeqId, RouteId, U64, U16, U64)](0)

  fun ref initialize(new_max_credits: ISize, step_type: String) =>
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
        None, SeqId, RouteId, U64, U16, U64)](_max_credits.usize())
      request_credits()
    end

  fun ref update_max_credits(max_credits: ISize) =>
    ifdef debug then
      Invariant(max_credits > 0)

      Invariant(_max_credits ==
        (_max_credits.usize() - 1).next_pow2().isize())
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
      if (_credits_available + credits) > _max_credits then
        _max_credits - _credits_available
      else
        credits
      end
    _credits_available = _credits_available + credits_recouped
    _step.recoup_credits(credits_recouped)
    if credits > credits_recouped then
      _consumer.return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32](
        "--Route (%s): rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n"
        .cstring(), _step_type.cstring(), credits, _credits_available - credits,
        _max_credits, _queue.size())
    end

    if _credits_available > 0 then
      if (_credits_available - credits_recouped) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _credits_exhausted()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      request_credits()
    end

  fun ref _credits_exhausted() =>
    _callback.credits_exhausted(_step)
    request_credits()

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

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
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
            _add_to_queue(metric_name, pipeline_time_spent, input, cfp, origin,
              msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts, metrics_id,
              worker_ingress_ts)
            _flush_queue()
          else
            _send_message_on_route(metric_name, pipeline_time_spent, input, cfp,
              origin, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
              metrics_id, worker_ingress_ts)
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
            @printf[I32]("----No credits: added msg to Route queue (%s)\n"
              .cstring(), _step_type.cstring())
          end
          _add_to_queue(metric_name, pipeline_time_spent, input, cfp,
            origin, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
            metrics_id, worker_ingress_ts)
          not (_queue.size() == _queue.max_size())
        end
      else
        _send_message_on_route(metric_name, pipeline_time_spent, input, cfp,
          origin, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
          metrics_id, worker_ingress_ts)
        true
      end
    else
      Fail()
      true
    end

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool
  =>
    // Forward should never be called on a TypedRoute
    Fail()
    true

  fun ref _send_message_on_route(metric_name: String, pipeline_time_spent: U64,
    input: In, cfp: Producer ref, i_origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    let o_seq_id = cfp.next_sequence_id()

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let new_metrics_id = ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name,
          "Before send to next step via behavior", metrics_id,
          latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    _consumer.run[In](metric_name,
      pipeline_time_spent,
      input,
      cfp,
      msg_uid,
      frac_ids,
      o_seq_id,
      _route_id,
      my_latest_ts,
      new_metrics_id,
      worker_ingress_ts)

    ifdef "trace" then
      @printf[I32]("Sent msg from Route (%s)\n".cstring(),
        _step_type.cstring())
    end

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1


  fun ref _add_to_queue(metric_name: String, pipeline_time_spent: U64, input: In,
    cfp: Producer ref, origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef debug then
      Invariant((_queue.max_size() > 0) and
        (_queue.size() < _queue.max_size()))
    end

    try
      _queue.enqueue((metric_name, pipeline_time_spent, input, cfp,
        origin, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts, metrics_id,
        worker_ingress_ts))
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
          d._7, d._8, d._9, d._10, d._11, d._12)
      end
    end

  fun ref _hard_flush() =>
    while (_queue.size() > 0) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6,
          d._7, d._8, d._9, d._10, d._11, d._12)
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
  var _step_type: String = ""
  let _callback: RouteCallbackHandler
  let _consumer: OutgoingBoundary
  let _metrics_reporter: MetricsReporter
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false

  // Store tuples of the form
  // (delivery_msg, pipeline_time_spent, cfp, i_origin, i_msg_uid, i_frac_ids,
  //  i_seq_id, i_route_id, latest_ts, metrics_id, metric_name, worker_ingress_ts)
  var _queue: FixedQueue[(ReplayableDeliveryMsg val, U64, Producer ref,
    Producer, U128, None, SeqId, RouteId, U64, U16, String, U64)]

  new create(step: Producer ref, consumer: OutgoingBoundary,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _callback.register(_step, this)
    _metrics_reporter = consume metrics_reporter
    _consumer.register_producer(_step)
    _queue = FixedQueue[(ReplayableDeliveryMsg val, U64, Producer ref,
      Producer, U128, None, SeqId, RouteId, U64, U16, String, U64)](0)

  fun ref initialize(new_max_credits: ISize, step_type: String) =>
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
      _queue = FixedQueue[(ReplayableDeliveryMsg val, U64, Producer ref, Producer,
        U128, None, SeqId, RouteId, U64, U16, String, U64)](_max_credits.usize())

      request_credits()
    end

  fun ref update_max_credits(max_credits: ISize) =>
    ifdef debug then
      Invariant(_max_credits ==
        (_max_credits.usize() - 1).next_pow2().isize())
    end
    ifdef debug then
      Invariant(max_credits > 0)
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
      if (_credits_available + credits) > _max_credits then
        _max_credits - _credits_available
      else
        credits
      end
    _credits_available = _credits_available + credits_recouped
    _step.recoup_credits(credits_recouped)
    if credits > credits_recouped then
      _consumer.return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32](
        "--BoundaryRoute (%s): rcvd %llu credits. Had %llu out of %llu. Queue size: %llu\n"
        .cstring(), _step_type.cstring(), credits,
        _credits_available - credits, _max_credits, _queue.size())
    end

    if _credits_available > 0 then
      if (_credits_available - credits_recouped) == 0 then
        _callback.credits_replenished(_step)
      end

      if (_queue.size() > 0) then
        _flush_queue()

        if _credits_available == 0 then
          _credits_exhausted()
        end
      end

      _request_more_credits_after =
        _credits_available - (_credits_available >> 2)
    else
      request_credits()
    end

  fun ref _credits_exhausted() =>
    _callback.credits_exhausted(_step)
    request_credits()

  fun ref request_credits() =>
    if not _request_outstanding then
      ifdef "credit_trace" then
        @printf[I32]("--BoundaryRoute (%s): requesting credits. Have %llu\n"
          .cstring(), _step_type.cstring(), _credits_available)
      end
      _consumer.credit_request(_step)
      _request_outstanding = true
    else
      ifdef "credit_trace" then
        @printf[I32]("----BoundaryRoute (%s): Request already outstanding\n"
          .cstring(), _step_type.cstring())
      end
    end

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    // Run should never be called on a BoundaryRoute
    Fail()
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool
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
            pipeline_time_spent,
            cfp,
            i_origin,
            msg_uid,
            i_frac_ids,
            i_seq_id,
            i_route_id,
            latest_ts,
            metrics_id,
            metric_name,
            worker_ingress_ts)
          _flush_queue()
        else
          _send_message_on_route(delivery_msg,
            pipeline_time_spent,
            cfp,
            i_origin,
            msg_uid,
            i_frac_ids,
            i_seq_id,
            _route_id,
            latest_ts,
            metrics_id,
            metric_name,
            worker_ingress_ts)
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
          pipeline_time_spent,
          cfp,
          i_origin,
          msg_uid,
          i_frac_ids,
          i_seq_id,
          i_route_id,
          latest_ts,
          metrics_id,
          metric_name,
          worker_ingress_ts)
        not (_queue.size() == _queue.max_size())
      end
    else
      _send_message_on_route(delivery_msg,
        pipeline_time_spent,
        cfp,
        i_origin,
        msg_uid,
        i_frac_ids,
        i_seq_id,
        _route_id,
        latest_ts,
        metrics_id,
        metric_name,
        worker_ingress_ts)
      true
    end

  fun ref _send_message_on_route(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64,
    cfp: Producer ref, i_origin: Producer, msg_uid: U128, i_frac_ids: None,
    i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64, metrics_id: U16,
    metric_name: String, worker_ingress_ts: U64)
  =>
    let o_seq_id = cfp.next_sequence_id()

    _consumer.forward(delivery_msg,
      pipeline_time_spent,
      cfp,
      msg_uid,
      i_frac_ids,
      o_seq_id,
      _route_id,
      latest_ts,
      metrics_id,
      metric_name,
      worker_ingress_ts)

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits_available = _credits_available - 1

  fun ref _add_to_queue(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64,
    cfp: Producer ref, i_origin: Producer, msg_uid: U128, i_frac_ids: None,
    i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64, metrics_id: U16,
    metric_name: String, worker_ingress_ts: U64)
  =>
    ifdef debug then
      Invariant((_queue.max_size() > 0) and
        (_queue.size() < _queue.max_size()))
    end

    // @printf[I32]("!!_q.max_size: %llu, q.size: %llu\n".cstring(),
      // _queue.max_size(), _queue.size())

    try
      _queue.enqueue((delivery_msg, pipeline_time_spent, cfp,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, metric_name, worker_ingress_ts))

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
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6, d._7,
          _route_id, d._9, d._10, d._11, d._12)
      end
    end

  fun ref _hard_flush() =>
    while (_queue.size() > 0) do
      try
        let d =_queue.dequeue()
        _send_message_on_route(d._1, d._2, d._3, d._4, d._5, d._6, d._7,
          _route_id, d._9, d._10, d._11, d._12)
      end
    end
