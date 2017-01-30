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
  var _step_type: String = ""
  let _step: Producer ref
  let _consumer: OutgoingBoundary
  let _metrics_reporter: MetricsReporter
  var _route: RouteLogic = _EmptyRouteLogic

  new create(step: Producer ref, consumer: OutgoingBoundary,
    metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _metrics_reporter = metrics_reporter
    _route = _RouteLogic(step, consumer, "Boundary")

  fun ref application_created() =>
    _consumer.register_producer(_step)

  fun ref application_initialized(step_type: String) =>
    _step_type = step_type
    _route.application_initialized(step_type)

  fun id(): U64 =>
    _route_id

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _route.dispose()

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
      match _step
      | let source: TCPSource ref =>
        Invariant(not source.is_muted())
      end
    end
    ifdef "trace" then
      @printf[I32]("Rcvd msg at BoundaryRoute (%s)\n".cstring(),
        _step_type.cstring())
    end
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
      o_seq_id,
      _route_id,
      latest_ts,
      metrics_id,
      worker_ingress_ts)

    ifdef "resilience" then
      cfp._bookkeeping(_route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

  fun ref request_ack() =>
    _consumer.request_ack()
