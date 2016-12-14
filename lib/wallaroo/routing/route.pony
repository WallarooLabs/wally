use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

trait Route
  fun ref application_created()
  fun ref application_initialized(new_max_credits: ISize, step_type: String)
  fun id(): U64
  fun ref receive_credits(credits: ISize)
  fun ref dispose()
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

trait RouteLogic
  fun ref application_initialized(new_max_credits: ISize, step_type: String)
  fun ref register_with_callback()
  fun ref receive_credits(credits: ISize)
  fun credits_available(): ISize
  fun ref use_credit()
  fun ref try_request(): Bool
  fun ref dispose()

class _RouteLogic is RouteLogic
  let _step: Producer ref
  let _consumer: CreditFlowConsumer
  var _step_type: String = ""
  var _route_type: String = ""
  let _callback: RouteCallbackHandler
  var _max_credits: ISize = 0 // This is updated on initialize()
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false

  var _credit_receiver: CreditReceiver = EmptyCreditReceiver

  new create(step: Producer ref, consumer: CreditFlowConsumer,
    handler: RouteCallbackHandler, r_type: String)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _route_type = r_type
    _credit_receiver = PreparingToWorkCreditReceiver(this)

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type
    ifdef "backpressure" then
      ifdef debug then
        Invariant(new_max_credits > 0)
      end
      _max_credits = new_max_credits

      _request_credits()
    end

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref register_with_callback() =>
    _callback.register(_step, this)

  fun ref update_max_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits > 0)
    end
    _max_credits = credits

  fun credits_available(): ISize =>
    _credits_available

  fun ref use_credit() =>
    _credits_available = _credits_available - 1

  fun max_credits(): ISize =>
    _max_credits

  fun ref _report_ready_to_work() =>
    _credit_receiver = WorkingCreditReceiver(this, _step_type, _route_type)
    match _step
    | let s: Step ref =>
      s.report_route_ready_to_work(this)
    end

  fun ref receive_credits(credits: ISize) =>
    _credit_receiver.receive_credits(credits)

  fun ref try_request(): Bool =>
    if _credits_available == 0 then
      _credits_exhausted()
      return false
    else
      if (_credits_available + 1) == _request_more_credits_after then
        // we started above the request size and finished below,
        // request credits
        _request_credits()
      end
    end
    true

  fun ref _credits_initialized() =>
    _callback.credits_initialized(_step, this)

  fun ref _recoup_credits(credits: ISize) =>
    _credits_available = _credits_available + credits
    _step.recoup_credits(credits)

  fun ref _credits_exhausted() =>
    _callback.credits_exhausted(_step)
    _request_credits()

  fun ref _credits_replenished() =>
    _callback.credits_replenished(_step)

  fun ref _update_request_more_credits_after(credits: ISize) =>
    _request_more_credits_after = credits

  fun ref _request_credits() =>
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

  fun ref _return_credits(credits: ISize) =>
    _consumer.return_credits(credits)

  fun ref _close_outstanding_request() =>
    _request_outstanding = false

class _EmptyRouteLogic is RouteLogic
  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    Fail()
    None
  fun ref register_with_callback() =>
    Fail()
    None
  fun ref receive_credits(credits: ISize) =>
    Fail()
    None
  fun credits_available(): ISize =>
    Fail()
    0
  fun ref use_credit() =>
    Fail()
    None
  fun ref try_request(): Bool =>
    Fail()
    true
  fun ref dispose() =>
    Fail()
    None

class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64()

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
