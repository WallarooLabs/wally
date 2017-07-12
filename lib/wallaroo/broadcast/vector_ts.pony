use "collections"
use "wallaroo/fail"

class val VectorTimestamp
  let _worker: String
  // !! Use persistent map to improve performance
  let _vs: Map[String, U64] val

  new val create(worker: String, vs: Map[String, U64] val =
    recover Map[String, U64] end)
  =>
    _worker = worker
    _vs = vs

  fun inc(): VectorTimestamp =>
    let new_map: Map[String, U64] trn = recover Map[String, U64] end
    for (k, v) in _vs.pairs() do
      new_map(k) = v
    end
    try
      new_map(_worker) = new_map(_worker) + 1
    else
      new_map(_worker) = 1
    end
    VectorTimestamp(_worker, consume new_map)

  fun for_worker(w: String): VectorTimestamp =>
    VectorTimestamp(w, _vs)

  fun merge(other: VectorTimestamp): VectorTimestamp =>
    let new_map: Map[String, U64] trn = recover Map[String, U64] end
    for (k, v) in _vs.pairs() do
      new_map(k) = v
    end
    for (k', v') in other._vs.pairs() do
      if new_map.contains(k') then
        try
          if v' > new_map(k') then
            new_map(k') = v'
          end
        else
          // This should never happen
          Fail()
        end
      else
        new_map(k') = v'
      end
    end
    VectorTimestamp(_worker, consume new_map)

  fun contains(k: String): Bool =>
    _vs.contains(k)

  fun val gt(other: VectorTimestamp): Bool =>
    other.is_subset_of(this) and
    (
      var none_less = true
      var at_least_one_greater = false
      for (k, v) in _vs.pairs() do
        try
          let v' = other._vs(k)
          if v < v' then
            none_less = false
          else
            if v > v' then at_least_one_greater = true end
          end
        else
          // This should never happen
          Fail()
        end
      end
      none_less and at_least_one_greater
    )

  fun val ge(other: VectorTimestamp): Bool =>
    other.is_subset_of(this) and
    (
      var none_less = true
      for (k, v) in _vs.pairs() do
        try
          if v < other._vs(k) then none_less = false end
        else
          // This should never happen
          Fail()
        end
      end
      none_less
    )

  fun val lt(other: VectorTimestamp): Bool =>
    is_subset_of(other) and
    (
      var none_greater = true
      var at_least_one_less = false
      for (k, v) in _vs.pairs() do
        try
          let v' = other._vs(k)
          if v > v' then
            none_greater = false
          else
            if v < v' then at_least_one_less = true end
          end
        else
          // This should never happen
          Fail()
        end
      end
      none_greater and at_least_one_less
    )

  fun val le(other: VectorTimestamp): Bool =>
    is_subset_of(other) and
    (
      var none_greater = true
      for (k, v) in _vs.pairs() do
        try
          if v > other._vs(k) then none_greater = false end
        else
          // This should never happen
          Fail()
        end
      end
      none_greater
    )

  fun val is_comparable(other: VectorTimestamp): Bool =>
    (this >= other) or (this <= other)

  fun val is_subset_of(other: VectorTimestamp): Bool =>
    for k in _vs.keys() do
      if not other.contains(k) then return false end
    end
    true
