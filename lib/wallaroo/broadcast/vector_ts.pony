use "collections"
use "wallaroo/fail"

class val VectorTimestamp
  let _worker: String
  // TODO: Use persistent map to improve performance
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
      var at_least_one_greater = false
      for (k, v) in _vs.pairs() do
        try
          let v' = other._vs(k)
          if v < v' then
            return false
          else
            if v > v' then at_least_one_greater = true end
          end
        end
      end
      at_least_one_greater or (_vs.size() > other._vs.size())
    )

  fun val ge(other: VectorTimestamp): Bool =>
    other.is_subset_of(this) and
    (
      for (k, v) in _vs.pairs() do
        try
          if v < other._vs(k) then return false end
        end
      end
      true
    )

  fun val lt(other: VectorTimestamp): Bool =>
    is_subset_of(other) and
    (
      var at_least_one_less = false
      for (k, v) in _vs.pairs() do
        try
          let v' = other._vs(k)
          if v > v' then
            return false
          else
            if v < v' then at_least_one_less = true end
          end
        else
          return false
        end
      end
      at_least_one_less or (other._vs.size() > _vs.size())
    )

  fun val le(other: VectorTimestamp): Bool =>
    is_subset_of(other) and
    (
      for (k, v) in _vs.pairs() do
        try
          if v > other._vs(k) then return false end
        else
          return false
        end
      end
      true
    )

  fun val is_comparable(other: VectorTimestamp): Bool =>
    (this >= other) or (this <= other)

  fun val is_subset_of(other: VectorTimestamp): Bool =>
    for k in _vs.keys() do
      if not other.contains(k) then return false end
    end
    true

  fun print() =>
    @printf[I32]("VTs{{{%s\n".cstring(), _worker.cstring())
    for (k, v) in _vs.pairs() do
      @printf[I32]("  %s: %s\n".cstring(), k.cstring(), v.string().cstring())
    end
    @printf[I32]("}}}\n".cstring())
