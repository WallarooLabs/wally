use "collections"

class Histogram
  """
  A Histogram where each value is counted into the bin of its next power of 2
  value. e.g. 3->bin:4, 4->bin:4, 5->bin:8, etc.

  In addition to the histogram itself, we are storing the min, max_value
  and total number of values seen (throughput) for reporting.
  """
  embed _counts: Array[U64] ref = Array[U64].init(0, 64)
  let _max_val: U64 = U64.max_value()
  var _min: U64 = U64.max_value()
  var _max: U64 = U64.min_value()

  fun get_idx(v: U64): USize =>
    """
    Return the power of 2 of the value to be used as its index in the histogram
    """
    64 - v.clz().usize()

  fun get(i: USize): U64 ? =>
    """
    Get the count at the i-th bin, raising an error if the index is out
    of bounds.
    """
    _counts(i)

  fun size(): U64 =>
    var s = U64(0)
    for i in _counts.values() do
      s = s + i
    end
    s

  fun ref apply(v: U64) =>
  """
  Count a U64 value in the correct bin in the histogram
  """
    let idx = get_idx(v)
    try
      _counts(idx) =  _counts(idx) + 1
      if v < _min then _min = v end
      if v > _max then _max = v end
    end
