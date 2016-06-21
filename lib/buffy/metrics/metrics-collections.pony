use "collections"

interface F64Selector
  fun apply(f: F64): F64
  fun bin(f: F64): F64
  fun bin_ceil(f: F64): F64
  fun bin_floor(f: F64): F64
  fun below(f: F64): F64
  fun above(f: F64): F64
  fun size(): USize
  fun bins(): Array[F64]
  fun overflow(): F64


class Log10Selector is F64Selector
"""
Associate values to bins in a log10 scale by rounding up
their log10 value to the nearest integer, with min_bin to specify the smallest
bin size, and max_bin to specify the size of the next-to-max bin size, such
that all values < min_bin associate to min_bin, and all values > max_bin
associate to Overflow.

E.g.
```
let s = Log10Selector(0.001, 10.0)
s(9) // -> 10.0
s(10.01) // -> Overflow
s(0.0001) // -> 0.001
```
"""
    let min_bin_ceil: F64
    let max_bin_ceil: F64
    let _max: F64 = F64.max_value()
    let _size: USize

  new val create(min_bin': F64=0.000001, max_bin': F64=10.0) =>
  """
  min_bin' denotes the maximum value in the smallest bin.
  max_bin' denotes the minimum value in the Overflow bin.
  All values below max_bin' are associate with the bin whose value is their
  log10 rounded up to the nearest integer.
  """
    min_bin_ceil = min_bin'
    max_bin_ceil = max_bin'
    _size = ((max_bin_ceil.log10() - min_bin_ceil.log10()) + 1).usize()

  fun size(): USize =>
    _size

  fun min_bin(): F64 =>
  """
  The minimum bin
  """
    min_bin_ceil

  fun max_bin(): F64 =>
  """
  The maximum non-overflow bin
  """
    max_bin_ceil

  fun overflow(): F64 =>
  """
  The ceiling value of the overflow bin
  """
    _max

  fun bins(): Array[F64] =>
    let bins' = Array[F64](size())
    for x in Range[I32](_log10int(min_bin_ceil),
                        _log10int(max_bin_ceil),
                        1) do
      bins'.push(F64(10).powi(x))
    end
    bins'.push(_max)
    bins'

  fun apply(f: F64): F64 =>
  """
  bin(f)
  """
    bin(f)

  fun _log10int(f: F64): I32 =>
  """
  The nearest integer >= log10(f)
  """
    f.log10().ceil().i32()

  fun bin(f: F64): F64 =>
  """
  The bin to which an F64 value is associated
  """
    if f > max_bin_ceil
    then _max
    else
      let b = F64(10).powi(_log10int(f))
      if b < min_bin_ceil
      then min_bin_ceil
      else b
      end
    end

  fun below(f: F64): F64 =>
  """
  The bin below the current bin
  """
    bin(bin_floor(bin(f)))

  fun above(f: F64): F64 =>
  """
  The bin above the current bin
  """
    bin(bin_ceil(bin(f)))

  fun bin_ceil(f: F64): F64 =>
  """
  The upper limit value of a bin
  """
    bin(f)

  fun bin_floor(f: F64): F64 =>
  """
  The lower limit value of a bin
  """
    if f == _max
      then max_bin_ceil
    elseif f <= min_bin_ceil
      then 0
    else
      F64(10).powi(_log10int((f)-1))
    end


class FixedBinSelector is F64Selector
"""
A log10 selector with increased granularity in the 0.1-10 range.
"""
    let min_bin_ceil: F64
    let max_bin_ceil: F64
    let _max: F64 = F64.max_value()
    let _size: USize
    let _bins: Array[F64]

  new val create() =>
  """
  """
  _bins = [0.000001, 0.00001, 0.0001, 0.001, 0.01, 0.05, 0.1, 0.15,
    0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7,
    0.75, 0.8, 0.85, 0.9, 0.95, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  _size = _bins.size()
  min_bin_ceil = 0.000001
  max_bin_ceil = 10

  fun size(): USize =>
    _size

  fun min_bin(): F64 =>
  """
  The minimum bin
  """
    min_bin_ceil

  fun max_bin(): F64 =>
  """
  The maximum non-overflow bin
  """
    max_bin_ceil

  fun overflow(): F64 =>
  """
  The ceiling value of the overflow bin
  """
    _max

  fun bins(): Array[F64] =>
    _bins.clone()

  fun apply(f: F64): F64 =>
  """
  bin(f)
  """
    bin(f)

  fun _binsearch(f: F64): (USize, F64) =>
  """
  Binary search for the correct bin
  """
  var l: USize = 0
  var r: USize = _bins.size() - 1
  var m: USize = (l+r)/2
  try
    while true do
      var v = _bins(m)
      if (l == r) or ((r-l) == 1) then break
      elseif v < f then
        l = m
        m = (l+r)/2
      elseif v >= f then
        r = m
        m = (l+r)/2
      end
    end
    var v = _bins(m)
    if f > v then return (m+1, _bins(m+1))
    else return (m, v)
    end
  else
    (_size, overflow())
  end

  fun bin(f: F64): F64 =>
  """
  The bin to which an F64 value is associated
  """
    if f > max_bin_ceil
    then _max
    else
      (let ind, let v) = _binsearch(f)
      v
    end

  fun below(f: F64): F64 =>
  """
  The bin below the current bin
  """
    if f > max_bin_ceil
    then max_bin_ceil
    else
      try
        (let ind, let f') = _binsearch(f)
        _bins(ind-1)
      else
        min_bin_ceil
      end
    end

  fun above(f: F64): F64 =>
  """
  The bin above the current bin
  """
    if f > max_bin_ceil
    then overflow()
    else
      try
        (let ind, let f') = _binsearch(f)
        _bins(ind+1)
      else
        max_bin_ceil
      end
    end

  fun bin_ceil(f: F64): F64 =>
  """
  The upper limit value of a bin
  """
    bin(f)

  fun bin_floor(f: F64): F64 =>
  """
  The lower limit value of a bin
  """
    if f == _max
      then max_bin_ceil
    elseif f <= min_bin_ceil
      then 0
    else
      try
        (let ind, let f') = _binsearch(f)
        _bins(ind-1)
      else
        min_bin_ceil
      end
    end


class LatencyHistogram
"""A fixed-bin histogram for aggregating individual MetricsReports
Events are anchored to a histogram based on their end_time
and to a bin based on the log10 value of end_time-start_time, rounded up
to the nearest integer.
"""

  let bin_selector: F64Selector val
  let sum_bins: Map[F64, F64]
  let count_bins: Map[F64, U64]
  var total: F64 = 0

  new create(bin_selector': F64Selector val) =>
    bin_selector = bin_selector'
    // initialize the sum and count histograms with zeros in each bin
    sum_bins = Map[F64, F64](bin_selector.size())
    count_bins = Map[F64, U64](bin_selector.size())
    for x in bin_selector.bins().values() do
      sum_bins.update(x, 0)
      count_bins.update(x,0)
    end

  fun ref apply(report: MetricsReport val) =>
    count_latency(report.dt())

  fun ref count_latency(dt:U64) =>
    // compute dt in seconds as F64 from the nanosecond U64 timestamps
    let dt':F64 = dt.f64().div(1_000_000_000.0)
    if dt' >= 0
    then
      let key = bin_selector(dt')
      try
        sum_bins.update(key, sum_bins(key)+dt')
        count_bins.update(key, count_bins(key)+1)
        total = total + 1
      end
    end

  fun size(): USize =>
    total.usize()

  fun hist_size(): USize =>
    count_bins.size()

  fun keys(): Array[F64] =>
    bin_selector.bins()

  fun values(): Array[(U64, F64)] =>
    var vals = Array[(U64, F64)]
    for key in count_bins.keys() do
      try
        vals.push((count_bins(key), sum_bins(key)))
      end
    end
    consume vals

  fun bin_percentiles(): Map[F64, F64] =>
    var percs = Map[F64, F64](count_bins.size())
    var current_total = F64(0)
    for k in bin_selector.bins().values() do
      try
        current_total = current_total + count_bins(k).f64()
        percs.update(k, current_total/total)
      end
    end
    consume percs

  fun bin_map(): Map[String, U64] =>
    var binmap = Map[String, U64]
    for (bin, count) in count_bins.pairs() do
      let key:String = if bin == bin_selector.overflow() 
                  then "overflow"
                  else bin.string() end
      binmap.update(key, count)
    end
    consume binmap

class ThroughputHistory
"""
A history of throughput counts per second
"""
  let _map: Map[U64, U64] = Map[U64, U64]
  var _start_time: U64 = 0
  var _end_time: U64 = 0

  fun ref apply(report: MetricsReport val) =>
    count_report(report.ended())

  fun ref count_report(end_time: U64) =>
    // Truncate nanoseconds to seconds
    let t': U64 = end_time.f64().div(1_000_000_000.0).ceil().u64()
    if _start_time == 0 then _start_time = t' end
    if t' > _end_time then _end_time = t' end
    _map.update(t', try _map(t') + 1 else 1 end)

  fun values(): Array[(U64, U64)] =>
  """
  The dense representation of the throughput history in the time ranges
  counted so far
  """
    let arr = Array[(U64, U64)](size())
    for ts in Range[U64](_start_time, (_end_time + 1), 1) do
      arr.push((ts, try _map(ts) else 0 end))
    end
    consume arr

  fun size(): USize =>
    ((_end_time - _start_time) + 1).usize()

type TimeBuckets is Map[U64, (LatencyHistogram, ThroughputHistory)]

type Steps is Set[U64]
type StepTimeranges is Map[U64, Steps]
type StepMetrics is Map[U64, TimeBuckets]

type Boundaries is Set[String]
type BoundaryTimeranges is Map[U64, Boundaries]
type BoundaryMetrics is Map[String, TimeBuckets]

type Sinks is Set[String]
type SinkTimeranges is Map[U64, Sinks]
type SinkMetrics is Map[String, TimeBuckets]

actor MetricsCollection
"""
A hierarchical collection of LatencyHistogram's and ThroughputHistory's keyed
on category and id
"""
  // Timeranges are anchored to the end of the time range
  var _stepmetrics: StepMetrics = StepMetrics
  var _steptimeranges: StepTimeranges = StepTimeranges
  var _boundarymetrics: BoundaryMetrics = BoundaryMetrics
  var _boundarytimeranges: BoundaryTimeranges = BoundaryTimeranges
  var _sinkmetrics: SinkMetrics = SinkMetrics
  var _sinktimeranges: SinkTimeranges = SinkTimeranges
  let _period: U64 val
  let _bin_selector: F64Selector val
  let _handler: MetricsCollectionOutputHandler val
  let _sink_type: U64 = BoundaryTypes.source_sink()
  let _egress_type: U64 = BoundaryTypes.ingress_egress()

  new create(bin_selector: F64Selector val, period: U64=1,
             handler: MetricsCollectionOutputHandler val) =>
    _period = period
    _bin_selector = bin_selector
    _handler = handler

  fun ref reset_collection() =>
    _stepmetrics = StepMetrics
    _steptimeranges = StepTimeranges
    _boundarymetrics = BoundaryMetrics
    _boundarytimeranges = BoundaryTimeranges
    _sinkmetrics = SinkMetrics
    _sinktimeranges = SinkTimeranges

  be process_summary(summary: (NodeMetricsSummary val |
                               BoundaryMetricsSummary val))
  =>
    match summary
    | let summary':NodeMetricsSummary val =>
      process_nodesummary(summary')
    | let summary':BoundaryMetricsSummary val =>
      process_boundarysummary(summary')
    end

  fun ref process_nodesummary(summary: NodeMetricsSummary val) =>
    for digest in summary.digests.values() do
      process_stepmetricsdigest(digest)
    end

  fun ref process_stepmetricsdigest(digest: StepMetricsDigest val) =>
    for report in digest.reports.values() do
      process_report(digest.step_id, report)
    end

  fun ref process_report(step_id: U64, report: StepMetricsReport val) =>
    let time_bucket: U64 = get_time_bucket(report.end_time)
    // Bookkeeping
    try
      _steptimeranges(time_bucket).set(step_id)
    else
      let steps' = Steps
      steps'.set(step_id)
      _steptimeranges.update(time_bucket, steps')
    end
    try
      let time_buckets:TimeBuckets = _stepmetrics(step_id)
      try
        (let lh, let th) = time_buckets(time_bucket)
        lh(report)
        th(report)
      else
        (let lh, let th) =(LatencyHistogram(_bin_selector),
                           recover ref ThroughputHistory end)
        lh(report)
        th(report)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _stepmetrics.update(step_id, time_buckets)
      (let lh, let th) = (LatencyHistogram(_bin_selector),
                          recover ref ThroughputHistory end)
      lh(report)
      th(report)
      time_buckets.update(time_bucket, (lh, th))
    end


  fun ref process_boundarysummary(summary: BoundaryMetricsSummary val) =>
    let name = summary.node_name
    for report in summary.reports.values() do
      match report.boundary_type
      | _egress_type => process_node(name, report)
      | _sink_type => process_sink(name, report)
      end
    end

  fun ref process_node(name: String, report: BoundaryMetricsReport val) =>
    let time_bucket: U64 = get_time_bucket(report.end_time)
    try
      _boundarytimeranges(time_bucket).set(name)
    else
      let boundaries' = Boundaries
      boundaries'.set(name)
      _boundarytimeranges.update(time_bucket, boundaries')
    end
    try
      let time_buckets: TimeBuckets = _boundarymetrics(name)
      try
        (let lh, let th) = time_buckets(time_bucket)
        lh(report)
        th(report)
      else
        (let lh, let th) = (LatencyHistogram(_bin_selector),
                            recover ref ThroughputHistory end)
        lh(report)
        th(report)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _boundarymetrics.update(name, time_buckets)
      (let lh, let th) = (LatencyHistogram(_bin_selector),
                          recover ref ThroughputHistory end)
      lh(report)
      th(report)
      time_buckets.update(time_bucket, (lh, th))
    end

  fun ref process_sink(name: String, report: BoundaryMetricsReport val) =>
    let time_bucket: U64 = get_time_bucket(report.end_time)
    try
      _sinktimeranges(time_bucket).set(name)
    else
      let sinks' = Sinks
      sinks'.set(name)
      _sinktimeranges.update(time_bucket, sinks')
    end
    try
      let time_buckets: TimeBuckets = _sinkmetrics(name)
      try
        (let lh, let th) = time_buckets(time_bucket)
        lh(report)
        th(report)
      else
        (let lh, let th) = (LatencyHistogram(_bin_selector),
                            recover ref ThroughputHistory end)
        lh(report)
        th(report)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _sinkmetrics.update(name, time_buckets)
      (let lh, let th) = (LatencyHistogram(_bin_selector),
                          recover ref ThroughputHistory end)
      lh(report)
      th(report)
      time_buckets.update(time_bucket, (lh, th))
    end

  fun get_time_bucket(time: U64): U64 =>
    (time/1_000_000_000) + (_period - ((time/1_000_000_000) % _period))

  be send_output(resumable: (Resumable tag | None) = None) =>
    handle_output()
    match resumable
    | let r: Resumable tag => r.resume()
    end

  fun ref handle_output() =>
    _handler.handle(_sinkmetrics, _boundarymetrics, _stepmetrics, _period)
    reset_collection()

interface Resumable
  be resume()
