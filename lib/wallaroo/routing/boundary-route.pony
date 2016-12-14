use "sendence/guid"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp-source"
use "wallaroo/topology"

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

  var _credit_receiver: CreditReceiver = EmptyCreditReceiver

  new create(step: Producer ref, consumer: OutgoingBoundary,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _metrics_reporter = metrics_reporter
    _credit_receiver = BoundaryRoutePreparingToWorkCreditReceiver(this)

  fun ref application_created() =>
    _callback.register(_step, this)
    _consumer.register_producer(_step)

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type
    ifdef "backpressure" then
      ifdef debug then
        Invariant(new_max_credits > 0)
      end
      _max_credits = new_max_credits

      request_credits()
    end

  fun ref update_max_credits(credits: ISize) =>
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

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

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

  fun ref _close_outstanding_request() =>
    _request_outstanding = false

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
    ifdef debug then
      ifdef "backpressure" then
        Invariant(_credits_available > 0)
      end
      match _step
      | let source: TCPSource ref =>
        Invariant(not source.is_muted())
      end
    end
    ifdef "trace" then
      @printf[I32]("Rcvd msg at BoundaryRoute (%s)\n".cstring(),
        _step_type.cstring())
    end
    ifdef "backpressure" then
      let above_request_point =
        _credits_available >= _request_more_credits_after

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

      if _credits_available == 0 then
        _credits_exhausted()
        return false
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
