use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

trait Route
  fun ref application_created()
  fun ref application_initialized(step_type: String)
  fun id(): U64
  fun ref dispose()
  // Return false to indicate queue is full and if producer is a Source, it
  // should mute
  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref, msg_uid: U128, frac_ids: None,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    msg_uid: U128, i_frac_ids: None, latest_ts: U64, metrics_id: U16,
    metric_name: String, worker_ingress_ts: U64): Bool

  fun ref request_ack()

trait RouteLogic
  fun ref application_initialized(step_type: String)
  fun ref dispose()

class _RouteLogic is RouteLogic
  let _step: Producer ref
  let _consumer: Consumer
  var _step_type: String = ""
  var _route_type: String = ""

  new create(step: Producer ref, consumer: Consumer, r_type: String) =>
    _step = step
    _consumer = consumer
    _route_type = r_type

  fun ref application_initialized(step_type: String) =>
    _step_type = step_type
    _report_ready_to_work()

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step)

  fun ref _report_ready_to_work() =>
    match _step
    | let s: Step ref =>
      s.report_route_ready_to_work(this)
    end

class _EmptyRouteLogic is RouteLogic
  fun ref application_initialized(step_type: String) =>
    Fail()
    None

  fun ref dispose() =>
    Fail()
    None

class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64()

  fun ref application_created() =>
    None

  fun ref application_initialized(step_type: String) =>
    None

  fun id(): U64 => _route_id
  fun ref dispose() => None
  fun ref request_ack() => None

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref, msg_uid: U128, frac_ids: None,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    Fail()
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    msg_uid: U128, i_frac_ids: None, latest_ts: U64, metrics_id: U16,
    metric_name: String, worker_ingress_ts: U64): Bool
  =>
    Fail()
    true
