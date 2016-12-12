use "buffered"
use "collections"
use "json"
use "net"
use "time"
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
  var _histogram: Histogram iso = Histogram

  new create(output_to': MetricsSink,
    app_name': String,
    worker_name': String,
    pipeline': String,
    metric_name': String,
    id': U16,
    prefix': String,
    category': MetricsCategory)
  =>
    _topic = "metrics:" + app_name'
    _pipeline = pipeline'
    _worker_name = worker_name'
    _id = id'
    _category = category'
    _metric_name = if prefix' != "" then
        prefix' + " " + metric_name'
      else
        metric_name'
      end

  fun ref report(duration: U64) =>
    _histogram(duration)

  fun ref topic(): String =>
    _topic

  fun ref metric_name(): String =>
    _metric_name

  fun ref pipeline(): String =>
    _pipeline

  fun ref worker_name(): String =>
    _worker_name

  fun ref id(): U16 =>
    _id

  fun ref category(): String =>
    _category()

  fun ref reset_histogram(): Histogram iso^ =>
    _histogram = Histogram

class MetricsReporter
  let _app_name: String
  let _worker_name: String
  let _metrics_conn: MetricsSink
  var _period_ends_at: U64 = 0
  let _period: U64
  let _wb: Writer = Writer

  let _step_metrics_map: Map[String, _MetricsReporter] =
    _step_metrics_map.create()

  let _pipeline_metrics_map: Map[String, _MetricsReporter] =
    _pipeline_metrics_map.create()

  let _worker_metrics_map: Map[String, _MetricsReporter] =
    _worker_metrics_map.create()

  new iso create(app_name: String, worker_name: String,
    metrics_conn: MetricsSink,
    period: U64 = 2_000_000_000)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _metrics_conn = metrics_conn
    _period = period
    let now = WallClock.nanoseconds()
    _period_ends_at = _next_period_endtime(now, period)

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

    _maybe_send_metrics()

  fun ref _next_period_endtime(time: U64, length: U64): U64 =>
    """
    Nanosecond end of the period in which time belongs
    """
    time + (length - (time % length))

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

    _maybe_send_metrics()

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
    _maybe_send_metrics()

  fun ref _maybe_send_metrics() =>
    let now = WallClock.nanoseconds()

    if now > _period_ends_at then
      let metrics = recover iso Array[(String, String, String, String, U16,
        Histogram iso, U64, U64, String, String)] end
      for mr in _step_metrics_map.values() do
        let h = mr.reset_histogram()
        let metric_name = mr.metric_name()
        let category = mr.category()
        let topic = mr.topic()
        let id = mr.id()
        let pipeline = mr.pipeline()
        let worker_name = mr.worker_name()
        metrics.push((metric_name, category, pipeline,
          worker_name, id, consume h, _period, _period_ends_at, topic, "metrics"))
      end
      for mr in _pipeline_metrics_map.values() do
        let h = mr.reset_histogram()
        let metric_name = mr.metric_name()
        let category = mr.category()
        let topic = mr.topic()
        let id = mr.id()
        let pipeline = mr.pipeline()
        let worker_name = mr.worker_name()
        metrics.push((metric_name, category, pipeline,
          worker_name, id, consume h, _period, _period_ends_at, topic, "metrics"))
      end
      for mr in _worker_metrics_map.values() do
        let h = mr.reset_histogram()
        let metric_name = mr.metric_name()
        let category = mr.category()
        let topic = mr.topic()
        let id = mr.id()
        let pipeline = mr.pipeline()
        let worker_name = mr.worker_name()
        metrics.push((metric_name, category, pipeline,
          worker_name, id, consume h, _period, _period_ends_at, topic, "metrics"))
      end
      _metrics_conn.send_metrics(consume metrics)
      _period_ends_at = _next_period_endtime(now, _period)
    end

  fun clone(): MetricsReporter iso^ =>
    MetricsReporter(_app_name, _worker_name, _metrics_conn)
