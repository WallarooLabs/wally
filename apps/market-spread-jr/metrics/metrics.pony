use "collections"
use "json"
use "net"
use "sendence/epoch"
use "sendence/hub"

type MetricsCategory is
  (ComputationCategory | StartToEndCategory | NodeIngressEgressCategory)

primitive ComputationCategory
  fun apply(): String => "computation"

primitive StartToEndCategory
  fun apply(): String => "start-to-end"

primitive NodeIngressEgressCategory
  fun apply(): String => "node-ingress-egress"

class MetricsReporter
  let _id: U64
  let _topic: String
  let _metric_name: String
  let _category: MetricsCategory
  let _period: U64
  let _output_to: TCPConnection
  var _histogram: Histogram = Histogram
  var _period_ends_at: U64 = 0

  new create(output_to: TCPConnection,
    id: U64,
    app_name: String,
    metric_name: String,
    category: MetricsCategory,
    period: U64 = 1_000_000_000)
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
    let payload = HubProtocol.metrics(_metric_name, _category(), _histogram)
    let hub_msg = HubProtocol.payload("metrics", _topic, payload)
    _output_to.writev(hub_msg)
