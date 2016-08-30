use "collections"
use "json"
use "sendence/epoch"

class MetricsReporter
  let _id: U64
  let _name: String
  let _category: String
  let _period: U64
  var _histogram: Histogram = Histogram
  var _period_ends_at: U64 = 0

  new iso create(id: U64,
    name: String,
    category: String,
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

/*
actor Metrics
  let _timelines: Array[TimelineCollector] = Array[TimelineCollector](1023)
  let free_candy: FreeCandy = FreeCandy(400)

  be run() =>
    for timeline in _timelines.values() do
      timeline.flush(free_candy)
    end

  be register(tc: TimelineCollector) =>
    _timelines.push(tc)



actor TimelineCollector
  """
  An actor responsible for collecting Timelines from a single step, node, or
  sink's MetricsRecorder
  """
  var _timelines: Array[Timeline iso] iso = recover Array[Timeline iso](2) end

  new create(metrics: Metrics) =>
    metrics.register(this)

  be apply(t: Timeline iso) =>
    """
    Add a new Timeline to the local collection
    """
    _timelines.push(consume t)

    if _timelines.size() > 2 then
      @printf[None]("overflow %zu\n".cstring(), _timelines.size())
    end

  be flush(free_candy: FreeCandy) =>
    let t: Array[Timeline iso] iso = _timelines = recover
      Array[Timeline iso](2)
    end

    while t.size() > 0 do
      try
        let json: (JsonArray val | None) = recover
          let tl: Timeline = t.pop()
          if tl.size() > 0 then
            tl.json()
          else
            None
          end
        end
        free_candy.accept(json)
      end
    end


class Timeline
  """
  The metrics timeline of a single step, boundary, or application,
  including both a latency histogram and a throughput history.
  """
  let _periods: Array[U64] = Array[U64](10)
  let _latencies: Array[PowersOf2Histogram] = Array[PowersOf2Histogram](10)
  var _current_period: U64 = 0
  let _period: U64
  let id: U64
  let name: String
  let category: String
  var _shift: USize = 0
  var _size: USize = 0

  new create(id': U64, name': String, category': String,
    period: U64 = 1_000_000_000)
  =>
    """
    `period` specifies the unit size for both latency measurement periods
    and the throughput history.
    """
    name = name'
    id = id'
    category = category'
    _period = period

  fun ref apply(dt: U64 val, end_time: (U64 | None)=None) =>
    match end_time
    | let ts: None =>
      _apply_to_ts(dt, Epoch.nanoseconds())
    | let ts: U64 =>
      _apply_to_ts(dt, ts)
    end

  fun ref _apply_to_ts(dt: U64 val, timestamp: U64) =>
    /*if timestamp > _current_period then
      // Create new entries in _periods, _latencies
      // and update _current_period and _current_index
      _current_period = _get_period(timestamp)
      _periods.push(_current_period)
      _latencies.push(PowersOf2Histogram)
      _size = _size + 1
    end
    */
    try
      _latencies(_size - 1)(dt)
    end

  fun size(): USize =>
    _periods.size()

  fun _get_period(time: U64): U64 =>
    """
    Nanosecond end of the period in which time belongs
    """
    time + (_period - (time % _period))

  fun json(): JsonArray ref^  =>
    var j: JsonArray ref = JsonArray(_size)
    /*
    for idx in Range[USize](_shift, _size, 1) do
      let t1: I64 = (_periods(idx)/1_000_000_000).i64()
      let t0: I64 = ((_periods(idx) - _period)/1_000_000_000).i64()
      let j': JsonObject ref = JsonObject
      j'.data.update("category", category)
      j'.data.update("pipeline_key", name)
      j'.data.update("t1", t1)
      j'.data.update("t0", t0)
      let topics: JsonObject ref = JsonObject
      j'.data.update("topics", topics)
      let latencies: JsonObject ref = JsonObject
      let throughputs: JsonObject ref = JsonObject
      topics.data.update("latency_bins", latencies)
      topics.data.update("throughput_out", throughputs)
      for (bin, count) in _latencies(idx).idx_pairs() do
        if count > 0 then
          latencies.data.update(bin.string(), count.i64())
        end
      end
      throughputs.data.update(t1.string(), _latencies(idx).size().i64())
      j.data.push(j')
    end
    */
    consume j

actor FreeCandy
  let _accept: Array[JsonArray val] iso

  new create(incoming: USize) =>
    _accept = recover iso Array[JsonArray val](incoming) end

  be accept(incoming: (JsonArray val | None)) =>
    None
    /*match incoming
    | let i: JsonArray val =>
      _accept.push(i)
    end
    */
*/

  /*
  class MetricsReporter
  let _id: U64
  let _name: String
  let _category: String
  let _period: U64
  //var _timeline: Timeline iso
  //var _timelinecollector: TimelineCollector
  let _histo: PowersOf2Histogram = PowersOf2Histogram

  new iso create(id: U64,
    name: String,
    category: String,
    metrics: Metrics,
    period: U64 = 1_000_000_000)
  =>
    _id = id
    _name = name
    _category = category
    _period = period
    //_timelinecollector = TimelineCollector(metrics)
    //_timeline = recover Timeline(_id, _name, _category, _period) end

  fun ref report(dt: U64) =>
    _histo(dt)
    //_timeline(dt)
    /*
    _timeline(dt)
    if (_timeline.size() > 1) then
      let t = _timeline = recover Timeline(_id, _name, _category, _period) end
      _timelinecollector(consume t)
    end
    */
    None
    */
