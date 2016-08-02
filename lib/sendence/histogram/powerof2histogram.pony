use "collections"

class PowersOf2Histogram
"""
A Histogram where each value is counted into the bin of its next power of 2
value. e.g. 3->bin:4, 4->bin:4, 5->bin:8, etc.
"""
  let _counts: Array[U64] ref
  let _max_val: U64 = U64.max_value()

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
    end

  fun ref update(i: USize, v: U64) ? =>
  """
  Update the value at index i to v, overwriting any existing value in that bin,
  raising an error if index is out of bounds.
  """
    _counts.update(i, v)

fun ref add(h: PowersOf2Histogram): PowersOf2Histogram ref =>
  """
  Add another histogram to the current histogram, returning a new histogram.
  """
    let h':PowersOf2Histogram = PowersOf2Histogram.from_array(_counts.clone())
    try
      for (i, v) in h.idx_pairs() do
        h'.update(i, h'.get(i) + v)
      end
    end
    consume h'

  fun ref sub(h: PowersOf2Histogram): PowersOf2Histogram ref =>
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
    consume h'

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
