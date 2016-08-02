use "collections"
use "sendence/histogram"

class ThroughputHistory
"""
A history of throughput counts per second
"""
  let _map: Map[U64, U64] = Map[U64, U64]
  var _max_time: U64 = U64.min_value()
  var _min_time: U64 = U64.max_value()

  fun ref apply(end_time: U64) =>
    // Round end_time down to nearest second
    let t': U64 = (end_time/1_000_000_000) + (if (end_time % 1_000_000_000) == 0
      then 0 else 1 end)
    _map.update(t', try _map(t') + 1 else 1 end)
    _max_time = _max_time.max(t')
    _min_time = _min_time.min(t')

  fun values(): ArrayValues[(U64, U64), Array[(U64, U64)]]^  =>
  """
  The dense representation of the throughput history in the time ranges
  counted so far
  """
    let s = size()
    let arr = Array[(U64, U64)](s)
    for ts in Range[U64](_min_time, (_max_time + 1), 1) do
      arr.push((ts, try _map(ts) else 0 end))
    end
    ArrayValues[(U64, U64), Array[(U64, U64)]](arr)

  fun size(): USize =>
    ((_max_time - _min_time) + 1).usize()

type TimeBuckets is Map[U64, (PowersOf2Histogram, ThroughputHistory)]

type Steps is Set[String]
type StepTimeranges is Map[U64, Steps]
type StepMetrics is Map[String, TimeBuckets]

type Boundaries is Set[String]
type BoundaryTimeranges is Map[U64, Boundaries]
type BoundaryMetrics is Map[String, TimeBuckets]

type Sinks is Set[String]
type SinkTimeranges is Map[U64, Sinks]
type SinkMetrics is Map[String, TimeBuckets]

actor MetricsCollection
"""
A hierarchical collection of PowersOf2Histograms and ThroughputHistorys keyed
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
  let _handler: MetricsCollectionOutputHandler val

  new create(period: U64=1_000_000_000,
             handler: MetricsCollectionOutputHandler val) =>
    _period = period
    _handler = handler

  be dispose() =>
    _handler.dispose()

  fun ref reset_collection() =>
    _stepmetrics = StepMetrics
    _steptimeranges = StepTimeranges
    _boundarymetrics = BoundaryMetrics
    _boundarytimeranges = BoundaryTimeranges
    _sinkmetrics = SinkMetrics
    _sinktimeranges = SinkTimeranges

  be process_step(step_name: String, start_time: U64, end_time: U64) =>
    _process_step(step_name, start_time, end_time)

  fun ref _process_step(step_name: String, start_time: U64, end_time: U64) =>
    let time_bucket: U64 = get_time_bucket(end_time)
    let dt: U64 = end_time - start_time
    // Bookkeeping
    try
      _steptimeranges(time_bucket).set(step_name)
    else
      let steps' = Steps
      steps'.set(step_name)
      _steptimeranges.update(time_bucket, steps')
    end
    try
      let time_buckets:TimeBuckets = _stepmetrics(step_name)
      try
        (let lh, let th) = time_buckets(time_bucket)
        lh(dt)
        th(dt)
      else
        (let lh, let th) =(PowersOf2Histogram,
                           recover ref ThroughputHistory end)
        lh(dt)
        th(dt)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _stepmetrics.update(step_name, time_buckets)
      (let lh, let th) = (PowersOf2Histogram,
                          recover ref ThroughputHistory end)
      lh(dt)
      th(dt)
      time_buckets.update(time_bucket, (lh, th))
    end

  be process_boundary(name: String, start_time: U64, end_time: U64) =>
    _process_boundary(name, start_time, end_time)

  fun ref _process_boundary(name: String, start_time: U64, end_time: U64) =>
    let time_bucket: U64 = get_time_bucket(end_time)
    let dt: U64 = end_time - start_time
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
        lh(dt)
        th(dt)
      else
        (let lh, let th) = (PowersOf2Histogram,
                            recover ref ThroughputHistory end)
        lh(dt)
        th(dt)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _boundarymetrics.update(name, time_buckets)
      (let lh, let th) = (PowersOf2Histogram,
                          recover ref ThroughputHistory end)
      lh(dt)
      th(dt)
      time_buckets.update(time_bucket, (lh, th))
    end

  be process_sink(name: String, start_time: U64, end_time: U64) =>
    _process_sink(name, start_time, end_time)

  fun ref _process_sink(name: String, start_time: U64, end_time: U64) =>
    let time_bucket: U64 = get_time_bucket(end_time)
    let dt: U64 = end_time - start_time
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
        lh(dt)
        th(dt)
      else
        (let lh, let th) = (PowersOf2Histogram,
                            recover ref ThroughputHistory end)
        lh(dt)
        th(dt)
        time_buckets.update(time_bucket, (lh, th))
      end
    else
      let time_buckets = TimeBuckets
      _sinkmetrics.update(name, time_buckets)
      (let lh, let th) = (PowersOf2Histogram,
                          recover ref ThroughputHistory end)
      lh(dt)
      th(dt)
      time_buckets.update(time_bucket, (lh, th))
    end

  fun get_time_bucket(time: U64): U64 =>
  """Use nanoseconds for the timebucket"""
    time + (_period - (time % _period))

  be send_output(resumable: (Resumable tag | None) = None) =>
    handle_output()
    match resumable
    | let r: Resumable tag => r.resume()
    end

  fun ref handle_output() =>
    _handler.handle(_sinkmetrics, _boundarymetrics, _stepmetrics, _period)
    reset_collection()

  be flush() =>
    send_output()

interface Resumable
  be resume()
