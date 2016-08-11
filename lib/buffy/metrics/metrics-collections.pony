use "collections"
use "json"
use "sendence/histogram"
use "sendence/epoch"

class Timeline
"""
The metrics timeline of a single step, boundary, or application, including both
a latency histogram and a throughput history.
"""
  let _offsets: Array[U64] = Array[U64](10).push(0)
  let _latencies: Array[PowersOf2Histogram] =
    Array[PowersOf2Histogram](10).push(PowersOf2Histogram)
  let _throughputs: Array[U64] = Array[U64](10).push(0)
  var _current_offset: U64
  var _current_index: USize = 0
  let _period: U64
  let name: String
  let category: String
  var _shift: USize = 0
  var _size: USize = 0
  var _base_time: U64 = 0

  new create(name': String, category': String,
    period: U64 = 1_000_000_000)
  =>
  """
  `period` specifies the unit size for both latency measurement periods
  and the throughput history.
  """
    name = name'
    category = category'
    _period = period
    _current_offset = 0
    _base_time = get_offset(Epoch.nanoseconds())

  fun ref apply(start_time: U64, end_time: U64) =>
    let dt = end_time - start_time
    if end_time > _current_offset then
      // Create new entries in _offsets, _latencies, and _throughputs
      // and update _current_offset and _current_index
      _current_offset = get_offset(end_time)
      _offsets.push(_current_offset)
      _latencies.push(PowersOf2Histogram)
      _throughputs.push(0)
      _current_index = _current_index + 1
      _size = _size + 1
    end
    // update latencies and throughputs
    try
      _latencies(_current_index)(dt)
      _throughputs(_current_index) = _throughputs(_current_index) + 1
    end

  fun size(): USize =>
    _size

  fun get_offset(time: U64): U64 =>
  """
  Nanosecond offset for the end_time of a measurement period
  """
    time + (_period - (time % _period))

  fun json(show_empty: Bool=false): JsonArray ref^ ? =>
    var j: JsonArray ref = JsonArray(_size)
    for idx in Range[USize](_shift, _size, 1) do
      let t1: I64 = ((_base_time + _offsets(idx))/1_000_000_000).i64()
      let t0: I64 = (((_base_time + _offsets(idx)) - _period)/1_000_000_000).i64()
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
        elseif show_empty then
          latencies.data.update(bin.string(), count.i64())
        end
      end
      throughputs.data.update(t1.string() , _throughputs(idx).i64())
      j.data.push(j')
    end
    consume j
