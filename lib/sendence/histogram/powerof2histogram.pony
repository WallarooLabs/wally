use "collections"

class PowersOf2Histogram
"""
A Histogram where each value is counted into the bin of its next power of 2
value. e.g. 3->bin:4, 4->bin:4, 5->bin:8, etc.
"""
  let _counts: Array[U64] ref
  let _max_val: U64 = U64.max_value()
  var _min: (U64|None) = None
  var _max: (U64|None) = None

  new ref create() =>
    _counts = Array[U64].init(0, 65)

  new ref from_array(arr: Array[U64] ref) =>
    _counts = arr

	fun get_idx(v: U64): USize =>
  """
  Return the power of 2 of the value to be used as its index in the histogram
  """
		64 - v.clz().usize()

  fun get(i: USize): U64 ? =>
  """
  Get the count at the i-th bin, raising an error if the index is out of bounds.
  """
    _counts(i)

  fun ref apply(v: U64) =>
  """
  Count a U64 value in the correct bin in the histogram
  """
		let idx = get_idx(v)
    try
      _counts.update(idx, _counts(idx) + 1)
      try
        if v < (_min as U64) then _min = v end
      else
        _min = v
      end
      try
        if v > (_max as U64) then _max = v end
      else
        _max = v
      end
    end

  fun ref update(i: USize, v: U64) ? =>
  """
  Update the value at index i to v, overwriting any existing value in that bin,
  raising an error if index is out of bounds.
  The values of `min()` and `max()` are updated as if the minimum value of the
  bin was counted for `min()` and as if the maximum value of the bin was counted
  for `max()`.
  """
    _counts.update(i, v)
    let mi = pow2(i-1)
    let ma = pow2(i)
    try
      if mi < (_min as U64) then _min = mi end
    else
      _min = mi
    end
    try
      if ma > (_max as U64) then _max = ma end
    else
      _max = ma
    end

  fun max(): U64 ? =>
    (_max as U64)

  fun min(): U64 ? =>
    (_min as U64)

  fun ref update_min(v: U64) =>
    _min = v

  fun ref update_max(v: U64) =>
    _max = v

  fun clone(): PowersOf2Histogram ref =>
  """
  Clone the current PowersOf2Histogram
  """
    let h': PowersOf2Histogram = PowersOf2Histogram.from_array(_counts.clone())
    try h'.update_min((_min as U64)) end
    try h'.update_max((_max as U64)) end
    consume h'

  fun add(h: PowersOf2Histogram): PowersOf2Histogram ref =>
  """
  Add another histogram to the current histogram, returning a new histogram.
  """
    let h':PowersOf2Histogram = PowersOf2Histogram.from_array(_counts.clone())
    try
      for (i, v) in h.idx_pairs() do
        h'.update(i, h'.get(i) + v)
      end
    end
    try h'.update_min((_min as U64)) end
    try h'.update_max((_max as U64)) end
    consume h'

  fun sub(h: PowersOf2Histogram): PowersOf2Histogram ref =>
  """
  Subtract another histogram from the current histogram, returning a new
  histogram.
  """
    let h':PowersOf2Histogram = PowersOf2Histogram.from_array(_counts.clone())
    try
      for (i, v) in h.idx_pairs() do
        h'.update(i, h'.get(i) - v)
      end
    end
    try h'.update_min((_min as U64)) end
    try h'.update_max((_max as U64)) end
    consume h'

  fun pow2(i: USize): U64 =>
		U64(1) << i.u64()

	fun idx_pairs(): ArrayPairs[U64, this->Array[U64]]^ =>
		_counts.pairs()

  fun pairs(): PowersOf2ArrayPairs[U64, this->Array[U64]]^ =>
		PowersOf2ArrayPairs[U64, this->Array[U64]](_counts)

  fun values(): ArrayValues[U64, this->Array[U64]]^ =>
    _counts.values()

  fun keys(): PowersOf2ArrayKeys[U64, this->Array[U64]]^ =>
		PowersOf2ArrayKeys[U64, this->Array[U64]](_counts)

class PowersOf2ArrayKeys[A, B: Array[A] #read] is Iterator[USize]
  let _array: B
  var _i: USize

  new create(array: B) =>
    _array = array
    _i = 0

  fun has_next(): Bool =>
    _i < _array.size()

  fun ref next(): USize =>
    if _i < _array.size() then
      pow2(_i = _i + 1)
    else
      pow2(_i)
    end

	fun pow2(i: USize): USize =>
		USize(1) << i

class PowersOf2ArrayPairs[A, B: Array[A] #read] is Iterator[(USize, B->A)]
  let _array: B
  var _i: USize

  new create(array: B) =>
    _array = array
    _i = 0

  fun has_next(): Bool =>
    _i < _array.size()

  fun ref next(): (USize, B->A) ? =>
    (pow2(_i), _array(_i = _i + 1))

  fun pow2(i: USize): USize =>
		USize(1) << i
