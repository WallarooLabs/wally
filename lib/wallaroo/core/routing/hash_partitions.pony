use "collections"
use "crypto"
use "wallaroo_labs/equality"
use "wallaroo_labs/mort"

class val HashPartitions is Equatable[HashPartitions]
  let _lower_bounds: Array[U128]
  let _nodes: Map[U128, String] = _nodes.create()

  new val create(nodes: Array[String] val) =>
    _lower_bounds = Array[U128]
    let count = nodes.size().u128()
    let part_size = U128.max_value() / count
    var next_lower_bound: U128 = 0
    for i in Range[U128](0, count) do
      _lower_bounds.push(next_lower_bound)
      try
        _nodes(next_lower_bound) = nodes(i.usize())?
      else
        @printf[I32]("What went wrong?\n".cstring())
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

  fun eq(that: box->HashPartitions): Bool =>
    ArrayEquality[U128](_lower_bounds, that._lower_bounds) and
      MapEquality[U128, String](_nodes, that._nodes)

  fun ne(that: box->HashPartitions): Bool => not eq(that)
