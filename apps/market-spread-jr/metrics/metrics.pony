use "collections"
use "json"
use "sendence/epoch"

type MetricsCategory is
  (ComputationCategory | StartToEndCategory | NodeIngressEgressCategory)

primitive ComputationCategory
  fun apply() => "computation"

primitive StartToEndCategory
  fun apply() => "start-to-end"

primitive NodeIngressEgressCategory
  fun apply() => "node-ingress-egress"

class MetricsReporter
  let _id: U64
  let _name: String
  let _category: MetricsCategory
  let _period: U64
  var _histogram: Histogram = Histogram
  var _period_ends_at: U64 = 0

  new create(id: U64,
    name: String,
    category: MetricsCategory,
    period: U64 = 1_000_000_000)
  =>
    _id = id
    _name = name
    _category = category
    _period = period
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

  fun _send_histogram(h: Histogram) =>
    None
