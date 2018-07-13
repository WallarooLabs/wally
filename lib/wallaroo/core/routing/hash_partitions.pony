use "collections"
use "crypto"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/equality"
use "wallaroo_labs/mort"

class val HashPartitions is Equatable[HashPartitions]
  let _lower_bounds: Array[U128]
  let _workers: Array[String] val
  let _nodes: Map[U128, String] = _nodes.create()

  new val create(nodes: Array[String] val) =>
    let unsorted_workers = Array[String]
    for n in nodes.values() do unsorted_workers.push(n) end
    let sorted_workers_ref = Sort[Array[String], String](unsorted_workers)
    let sorted_workers = recover trn Array[String] end
    for w in sorted_workers_ref.values() do
      sorted_workers.push(w)
    end
    _workers = consume sorted_workers
    _lower_bounds = Array[U128]
    let count = nodes.size().u128()
    let part_size = U128.max_value() / count
    var next_lower_bound: U128 = 0
    for i in Range[U128](0, count) do
      _lower_bounds.push(next_lower_bound)
      try
        _nodes(next_lower_bound) = nodes(i.usize())?
      else
        Fail()
      end
      next_lower_bound = next_lower_bound + part_size
    end

  fun get_claimant(hash: U128): String ? =>
    var next_to_last_idx: USize = _lower_bounds.size() - 1
    var last_idx: USize = 0

    if hash > _lower_bounds(next_to_last_idx)? then
      return _nodes(_lower_bounds(next_to_last_idx)?)?
    end

    // Binary search
    while true do
      let next_lower_bound = _lower_bounds(last_idx)?

      if hash >= next_lower_bound then
        if hash < _lower_bounds(last_idx + 1)? then
          return _nodes(next_lower_bound)?
        else
          var step =
            (next_to_last_idx.isize() - last_idx.isize()).abs().usize() / 2
          if step == 0 then step = 1 end
          next_to_last_idx = last_idx
          last_idx = last_idx + step
        end
      else
        var step =
          (next_to_last_idx.isize() - last_idx.isize()).abs().usize() / 2
        if step == 0 then step = 1 end
        next_to_last_idx = last_idx
        last_idx = last_idx - step
      end
    end
    Unreachable()
    ""

  fun get_claimant_by_key(key: ByteSeq): String ? =>
    var hashed_key: U128 = 0
    for v in MD5(key).values() do
      hashed_key = (hashed_key << 8) + v.u128()
    end
    get_claimant(hashed_key)?

  fun claimants(): Iterator[String] ref =>
    _nodes.values()

  // !@ This is crudely recalculating from scratch.  We need to move as few
  // keys as possible.
  fun add_claimants(cs: Array[String] val): HashPartitions ? =>
    let new_ws = recover trn Array[String] end
    for w in _workers.values() do
      new_ws.push(w)
    end
    for w in cs.values() do
      if ArrayHelpers[String].contains[String](_workers, w) then error end
      new_ws.push(w)
    end
    // We're relying on the fact that the workers are sorted here when
    // HashPartitions is created to ensure that this always leads to the
    // same partitioning.
    HashPartitions(consume new_ws)

  // !@ This is crudely recalculating from scratch.  We need to move as few
  // keys as possible.
  fun remove_claimants(to_remove: Array[String] val): HashPartitions ? =>
    let new_ws = recover trn Array[String] end
    for w in to_remove.values() do
      if not ArrayHelpers[String].contains[String](_workers, w) then error end
    end
    for w in _workers.values() do
      if not ArrayHelpers[String].contains[String](to_remove, w) then
        new_ws.push(w)
      end
    end
    // We're relying on the fact that the workers are sorted here when
    // HashPartitions is created to ensure that this always leads to the
    // same partitioning.
    HashPartitions(consume new_ws)

  fun eq(that: box->HashPartitions): Bool =>
    ArrayEquality[U128](_lower_bounds, that._lower_bounds) and
      MapEquality[U128, String](_nodes, that._nodes)

  fun ne(that: box->HashPartitions): Bool => not eq(that)
