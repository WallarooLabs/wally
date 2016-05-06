use "collections"


interface BinSelector
  fun apply(v: F64): F64
  fun ceil(v: F64): F64
  fun floor(v: F64): F64
  fun bin_ceil(v: F64): F64
  fun bin_floor(v: F64): F64
  fun min_bin(): F64
  fun max_bin(): F64
  fun size(): USize
  fun bins(): Array[F64]


class Log10Selector is BinSelector
    let min_bin_ceil: F64
    let max_bin_ceil: F64
    let max_bin_val: F64 = F64.max_value()
    let _size: USize

  new create(min_bin': F64=0.000001, max_bin': F64=1.0) =>
    min_bin_ceil = min_bin'
    max_bin_ceil = max_bin'
    _size = ((max_bin_ceil.log10() - min_bin_ceil.log10()) + 1).usize()

  fun size(): USize =>
    _size

  fun min_bin(): F64 =>
    min_bin_ceil

  fun max_bin(): F64 => 
    max_bin_ceil

  fun bins(): Array[F64] =>
    let bins' = Array[F64](size())
    for x in Range[F64](min_bin_ceil.log10().floor(),
                        max_bin_ceil.log10().ceil(),
                        1) do
      bins'.push(x)
    end
    bins'

  fun apply(v: F64): F64 =>
  """
  Select the bin whose value is the log10 ceiling raised to the power of 10
  """
    ceil(v)

  fun ceil(v: F64): F64 =>
    let ceil_val: F64 = F64(10).pow(v.log10().ceil())
    if ceil_val > max_bin_ceil
    then max_bin_val
    else ceil_val
    end

  fun floor(v: F64): F64 =>
    F64(10).pow(v.log10().floor())

  fun bin_ceil(v: F64): F64 =>
    ceil(v)

  fun bin_floor(v: F64): F64 =>
    let bin_floor_val: F64 = F64(10).pow(v.log10().floor() - 1)
    if bin_floor_val < min_bin_ceil
    then min_bin_ceil
    else bin_floor_val
    end


class MetricsHistogram
"""A fixed-bin histogram for aggregating individual MetricsReports
Events are anchored to a histogram based on their start_time
and to a bin based on their log10 value, rounded up.
"""

  let type_name: String
  let id: I32
  let bin_selector: BinSelector
  let sum_bins: Map[F64, F64]
  let count_bins: Map[F64, U64]
  var start_time: F64
  var end_time: F64
  var total: F64 = 0

  new create(id': I32, type_name': String, bin_selector': BinSelector,
             start_time': F64, end_time': F64) =>
    id = id'
    type_name = type_name'
    bin_selector = bin_selector'
    start_time = start_time'
    end_time = end_time'
    // initialize the sum and count histograms with zeros in each bin
    sum_bins = Map[F64, F64](bin_selector.size())
    count_bins = Map[F64, U64](bin_selector.size())
    for x in bin_selector.bins().values() do
      sum_bins.update(x, 0)
      count_bins.update(x,0)
    end

  fun ref count_report(report: MetricsReport) =>
    let dt = report.dt()
    if dt > 0
    then
      let key = bin_selector(dt)
      try
        sum_bins.update(dt, sum_bins(dt)+dt)
        count_bins.update(dt, count_bins(dt)+1)
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
