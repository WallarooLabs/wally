use "collections"
use "json"
use "net"
use "time"
use "buffered"
use "sendence/hub"
use "sendence/epoch"

type MetricsCategory is
  (ComputationCategory | StartToEndCategory | NodeIngressEgressCategory)

primitive ComputationCategory
  fun apply(): String => "computation"

primitive StartToEndCategory
  fun apply(): String => "start-to-end"

primitive NodeIngressEgressCategory
  fun apply(): String => "node-ingress-egress"

class _MetricsReporter
  let _id: U64
  let _topic: String
  let _metric_name: String
  let _category: MetricsCategory
  let _period: U64
  let _output_to: TCPConnection
  var _histogram: Histogram = Histogram
  var _period_ends_at: U64 = 0
  let _wb: Writer = Writer

  new create(output_to: TCPConnection,
    id: U64,
    app_name: String,
    metric_name: String,
    category: MetricsCategory,
    period: U64 = 2_000_000_000)
  =>
    _id = id
    _topic = "metrics:" + app_name
    _metric_name = metric_name
    _category = category
    _period = period
    _output_to = output_to
    let now = Epoch.nanoseconds()
    _period_ends_at = _next_period_endtime(now, period)

  fun ref report(duration: U64) =>
    let now = Epoch.nanoseconds()

    if now > _period_ends_at then
      _period_ends_at = _next_period_endtime(now, _period)
      let h = _histogram = Histogram
      _send_histogram(h)
    end
    _histogram(duration)

  fun _next_period_endtime(time: U64, length: U64): U64 =>
    """
    Nanosecond end of the period in which time belongs
    """
    time + (length - (time % length))

  fun ref _send_histogram(h: Histogram) =>
    let payload = HubProtocol.metrics(_metric_name, _category(), h,
      _period, _period_ends_at, _wb)
    let hub_msg = HubProtocol.payload("metrics", _topic, payload)
    _output_to.writev(hub_msg)

class MetricsReporter
  let _app_name: String
  let _metrics_conn: TCPConnection
  let _step_metrics_map: Map[String, _MetricsReporter] =
    _step_metrics_map.create()
  let _pipeline_metrics_map: Map[String, _MetricsReporter] =
    _pipeline_metrics_map.create()

  new iso create(app_name: String, metrics_conn: TCPConnection) =>
    _app_name = app_name
    _metrics_conn = metrics_conn

  fun ref step_metric(name: String, start_ts: U64, end_ts: U64) =>
     let metrics = try
      _step_metrics_map(name)
    else
      let reporter =
        _MetricsReporter(_metrics_conn, 1, _app_name, name, 
          ComputationCategory)
      _step_metrics_map(name) = reporter
      reporter
    end

    metrics.report(end_ts - start_ts)

  fun ref pipeline_metric(source_name: String val, source_ts: U64) =>
    let metrics = try
        _pipeline_metrics_map(source_name)
      else
        let reporter =
          _MetricsReporter(_metrics_conn, 1, _app_name, source_name, 
            StartToEndCategory)
        _pipeline_metrics_map(source_name) = reporter
        reporter
      end

    metrics.report(Time.nanos() - source_ts)
