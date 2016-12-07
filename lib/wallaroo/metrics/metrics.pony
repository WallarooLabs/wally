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
      let h = _histogram = Histogram
      _send_histogram(h)
      _period_ends_at = _next_period_endtime(now, _period)
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
  let _worker_name: String
  let _metrics_conn: TCPConnection
  let _step_metrics_map: Map[String, _MetricsReporter] =
    _step_metrics_map.create()
  let _pipeline_metrics_map: Map[String, _MetricsReporter] =
    _pipeline_metrics_map.create()

  new iso create(app_name: String, metrics_conn: TCPConnection, 
    worker_name: String = "W")
  =>
    _app_name = app_name
    _metrics_conn = metrics_conn
    _worker_name = worker_name

  fun ref step_metric(pipeline: String, name: String, num: U16, start_ts: U64,
    end_ts: U64, prefix: String = "")
  =>
    let metric_name: String val = ifdef "detailed-metrics" then
      let str_size = _worker_name.size() + pipeline.size() + name.size() + 
        prefix.size() + 14
      let metric_name_tmp = recover String(str_size) end
      metric_name_tmp.append(pipeline)
      metric_name_tmp.append("@")
      metric_name_tmp.append(_worker_name)
      metric_name_tmp.append(": ")
      metric_name_tmp.append(num.string())
      metric_name_tmp.append(" - ")
      if prefix != "" then
        metric_name_tmp.append(prefix)
        metric_name_tmp.append(" ")
      end
      metric_name_tmp.append(name)
      consume metric_name_tmp
    else
      name
    end
    let metrics = try
      _step_metrics_map(metric_name)
    else
      let reporter =
        _MetricsReporter(_metrics_conn, 1, _app_name, metric_name,
          ComputationCategory)
      _step_metrics_map(metric_name) = reporter
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

    metrics.report(Epoch.nanoseconds() - source_ts) // might be across workers

  fun clone(): MetricsReporter iso^ =>
    MetricsReporter(_app_name, _metrics_conn, _worker_name)
