use "collections"
use "json"
use "net"
use "time"
use "buffered"
use "sendence/hub"
use "sendence/wall-clock"

type MetricsCategory is
  (ComputationCategory | StartToEndCategory | NodeIngressEgressCategory)

primitive ComputationCategory
  fun apply(): String => "computation"

primitive StartToEndCategory
  fun apply(): String => "start-to-end"

primitive NodeIngressEgressCategory
  fun apply(): String => "node-ingress-egress"

class _MetricsReporter
  let _topic: String
  let _metric_name: String
  let _pipeline: String
  let _id: U16
  let _worker_name: String
  let _category: MetricsCategory
  let _period: U64
  let _output_to: TCPConnection
  var _histogram: Histogram = Histogram
  var _period_ends_at: U64 = 0
  let _wb: Writer = Writer

  new create(output_to': TCPConnection,
    app_name': String,
    worker_name': String,
    pipeline': String,
    metric_name': String,
    id': U16,
    prefix': String,
    category': MetricsCategory,
    period': U64 = 2_000_000_000)
  =>
    _topic = "metrics:" + app_name'
    _pipeline = pipeline'
    _worker_name = worker_name'
    _id = id'
    _category = category'
    let str_size = _worker_name.size() + _pipeline.size() + metric_name'.size() +
      prefix'.size() + 14
    let metric_name_tmp = recover String(str_size) end
    metric_name_tmp.append(_pipeline)
    metric_name_tmp.append("@")
    metric_name_tmp.append(_worker_name)
    metric_name_tmp.append(": ")
    metric_name_tmp.append(_id.string())
    metric_name_tmp.append(" - ")
    if prefix' != "" then
      metric_name_tmp.append(prefix')
      metric_name_tmp.append(" ")
    end
    metric_name_tmp.append(metric_name')
    _metric_name = consume metric_name_tmp

    _period = period'
    _output_to = output_to'
    let now = WallClock.nanoseconds()
    _period_ends_at = _next_period_endtime(now, period')

  fun ref report(duration: U64) =>
    let now = WallClock.nanoseconds()

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

  let _worker_metrics_map: Map[String, _MetricsReporter] =
    _worker_metrics_map.create()

  new iso create(app_name: String, worker_name: String,
    metrics_conn: TCPConnection)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _metrics_conn = metrics_conn

  fun ref step_metric(pipeline: String, name: String, id: U16, start_ts: U64,
    end_ts: U64, prefix: String = "")
  =>
    // TODO: Figure out how to switch to a map without a performance penalty
    // such as: `MapIs[(String, String, U16, String), _MetricsReporter]`
    // NOTE: Previous attempt to switch to the tuple map resulted in a
    // negative performance impact so that is why the following string concat is
    // still being used.
    let metric_name: String val = ifdef "detailed-metrics" then
      let str_size = _worker_name.size() + pipeline.size() + name.size() +
        prefix.size() + 6
      let metric_name_tmp = recover String(str_size) end
      metric_name_tmp.append(pipeline)
      metric_name_tmp.append(_worker_name)
      metric_name_tmp.append(id.string())
      if prefix != "" then
        metric_name_tmp.append(prefix)
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
        _MetricsReporter(_metrics_conn, _app_name, _worker_name, pipeline,
          name, id, prefix, ComputationCategory)
      _step_metrics_map(metric_name) = reporter
      reporter
    end

    metrics.report(end_ts - start_ts)

  fun ref pipeline_metric(source_name: String val, time_spent: U64) =>
    let metrics = try
        _pipeline_metrics_map(source_name)
      else
        let reporter =
          _MetricsReporter(_metrics_conn, _app_name, _worker_name, source_name,
            source_name, 0, "", StartToEndCategory)
        _pipeline_metrics_map(source_name) = reporter
        reporter
      end

    metrics.report(time_spent)

  fun ref worker_metric(pipeline_name: String val, time_spent: U64) =>
    let metrics = try
        _worker_metrics_map(pipeline_name)
      else
        let reporter =
          _MetricsReporter(_metrics_conn, _app_name, _worker_name, pipeline_name,
            _worker_name, 0, "", NodeIngressEgressCategory)
        _worker_metrics_map(pipeline_name) = reporter
        reporter
      end

    metrics.report(time_spent)

  fun clone(): MetricsReporter iso^ =>
    MetricsReporter(_app_name, _worker_name, _metrics_conn)
