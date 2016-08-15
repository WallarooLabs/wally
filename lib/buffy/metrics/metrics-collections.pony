use "collections"
use "json"
use "sendence/histogram"
use "sendence/epoch"

class Timeline
"""
The metrics timeline of a single step, boundary, or application, including both
a latency histogram and a throughput history.
"""
  let _periods: Array[U64] = Array[U64](10)
  let _latencies: Array[PowersOf2Histogram] = Array[PowersOf2Histogram](10)
  var _current_period: U64 = 0
  var _current_index: USize = 0
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

  fun ref apply(start_time: U64, end_time: U64) =>
    let dt = end_time - start_time
    if end_time > _current_period then
      // Create new entries in _periods, _latencies
      // and update _current_period and _current_index
      _current_period = get_period(end_time)
      _periods.push(_current_period)
      _latencies.push(PowersOf2Histogram)
      _size = _size + 1
      _current_index = _size - 1
    end
    // update latencies
    try
      _latencies(_current_index)(dt)
    end

  fun size(): USize =>
    _periods.size()

  fun get_period(time: U64): U64 =>
  """
  Nanosecond end of the period in which time belongs
  """
    time + (_period - (time % _period))

  fun json(show_empty: Bool=false): JsonArray ref^ ? =>
    var j: JsonArray ref = JsonArray(_size)
    for idx in Range[USize](_shift, _size, 1) do
      let t1: I64 = (_periods(idx)/1_000_000_000).i64()
      let t0: I64 = ((_periods(idx) - _period)/1_000_000_000).i64()
      let j': JsonObject ref = JsonObject
      j'.data.update("category", category)
      j'.data.update("pipeline_key", recover
        let s = String(30)
        s.append(name)
        s.append(":")
        s.append(id.string())
        consume s
        end)
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
        elseif show_empty then
          latencies.data.update(bin.string(), count.i64())
        end
      end
      throughputs.data.update(t1.string() , _latencies(idx).size().i64())
      j.data.push(j')
    end
    consume j
