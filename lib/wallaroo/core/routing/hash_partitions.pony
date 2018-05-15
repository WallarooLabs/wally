use "collections"
use "crypto"
use "wallaroo_labs/mort"

class val HashPartitions is (Equatable[HashPartitions] & Stringable)
  let _lower_bounds: Array[U128] = _lower_bounds.create()
  let _interval_sizes: Array[U128] = _interval_sizes.create()
  let _lb_to_c: Map[U128, String] = _lb_to_c.create()  // lower bound -> claimant

  new val create(cs: Array[String] val) =>
    """
    Given an array of claimant name strings that are non-zero length,
    create a HashPartitions that assigns equal weight to all claimants.
    """
    let sizes: Array[(String, U128)] iso = recover sizes.create() end
    let interval: U128 = if cs.size() == 0 then
      U128.max_value()
    else
      U128.max_value() / cs.size().u128()
    end

    for c in cs.values() do
      if c != "" then
        sizes.push((c, interval))
      end
    end
    create2(consume sizes)

  new val create_with_weights(weights: Array[(String, F64)] val,
    decimal_digits: USize = 2)
  =>
    """
    Given an array of 2-tuples (claimant name strings that are
    non-zero length plus floating point weighting factor for the claimant),
    create a HashPartitions that assigns equal weight to all claimants.
    """
    let weights': Array[(String, F64)] trn = recover weights'.create() end
    var sum: F64 = 0.0
    let sizes: Array[(String, U128)] trn = recover sizes.create() end

    for (c, w) in weights.values() do
      let w' = RoundF64(w, decimal_digits)
      if (c != "") and (w' > 0.0) then
        weights'.push((c, w'))
      end
    end

    for (_, w) in weights'.values() do
      sum = sum + w
    end
    for (c, w) in weights'.values() do
      if w == sum then
        sizes.push((c, U128.max_value()))
      else
        let fraction: F64 = w / sum
        let sz': F64 = U128.max_value().f64() * fraction
        let sz: U128 = U128.from[F64](sz')
        sizes.push((c, sz))
      end
    end
    create2(consume sizes)

  new val create_with_sizes(sizes: Array[(String, U128)] val) =>
    create2(sizes)

  fun adjust_weights(new_weights: Array[(String, F64)] val,
    decimal_digits: USize = 2): HashPartitions
   =>
    """
    Given a previously-built HashPartitions object, make some adjustments
    simultaneously to any/all of the following dimensions for one or more
    claimants and return a new HashPartitions object:

    1. Change weight of the existing claimant.
    2. Add a new claimant by dividing all existing interval assignments
       proportionally by weight.
    3. Remove an existing claimant by reassigning all interval assignments
       for that client to remaining clients proportionally by weight.

    It is possible to use weight assignment less than 1.0 but is not
    recommended.  Future use of adjust_weights() and related functions
    will re-normalize total weight assignments based on the smallest
    claim interval sum and will assign a weight of 1.0 to that sum.
    """
    _adjust_weights(new_weights, decimal_digits)

fun add_claimants(cs: Array[String] val, decimal_digits: USize = 2):
  HashPartitions ?
=>
  """
  A wrapper around adjust_weights() where we wish only to add new
  claimants with weight 1.0 to this HashPartitions and return a new
  HashPartitions object.

  This function is partial: it is an error if we try to add a claimant
  name that already exists in this HashPartitions.
  """
  let current_weights = get_weights_normalized(decimal_digits)
  let new_weights: Array[(String, F64)] iso = recover new_weights.create() end

  for c in cs.values() do
    if current_weights.contains(c) then
      error
    end
  end
  for (c, w) in current_weights.pairs() do
    new_weights.push((c, w))
  end
  for c in cs.values() do
    new_weights.push((c, 1.0))
  end
  let new_weights' = recover val consume new_weights end
  if get_weights_normalized().size() == 0 then
    create_with_weights(new_weights', decimal_digits)
  else
    adjust_weights(new_weights', decimal_digits)
  end

fun remove_claimants(cs: Array[String] val, decimal_digits: USize = 2):
  HashPartitions ?
=>
  """
  A wrapper around adjust_weights() where we wish only to remove
  existing claimants from this HashPartitions and return a new
  HashPartitions object.

  This function is partial: it is an error if we try to remove a claimant
  name that does not exist in this HashPartitions.
  """
  let current_weights = get_weights_normalized(decimal_digits)
  let new_weights: Array[(String, F64)] trn = recover new_weights.create() end
  var rs: Set[String] = rs.create()

  for c in cs.values() do
    if not current_weights.contains(c) then
      error
    end
    rs = rs.add(c)
  end
  for (c, w) in current_weights.pairs() do
    if not rs.contains(c) then
      new_weights.push((c, w))
    end
  end
  adjust_weights(consume new_weights, decimal_digits)

fun ref create2(sizes: Array[(String, U128)] val) =>
    """
    Create a HashPartitions using U128-sized intervals.
    """
    let count = sizes.size()
    var next_lower_bound: U128 = 0

    if sizes.size() == 0 then
      return
    end
    try
      for i in Range[USize](0, count) do
        let c = sizes(i)?._1
        let interval = sizes(i)?._2
        _lower_bounds.push(next_lower_bound)
        _interval_sizes.push(interval)
        _lb_to_c(next_lower_bound) = c
        next_lower_bound = next_lower_bound + interval
      end
    else
      Fail()
    end

    var sum: U128 = 0
    for interval in _interval_sizes.values() do
      sum = sum + interval
    end
    let idx = _lower_bounds.size() - 1
    let i_adjust = (U128.max_value() - sum)
    try _interval_sizes(idx)? = _interval_sizes(idx)? + i_adjust
      else Fail() end

  fun box eq(y: HashPartitions box): Bool =>
    """
    Implement eq for Equatable trait.
    """
    try
      if (_lower_bounds.size() == y._lower_bounds.size()) and
         (_interval_sizes.size() == y._interval_sizes.size()) and
         (_lb_to_c.size() == y._lb_to_c.size())
      then
        for i in _lower_bounds.keys() do
          if (_lower_bounds(i)? != y._lower_bounds(i)?) or
             (_interval_sizes(i)? != y._interval_sizes(i)?) or
             (_lb_to_c(_lower_bounds(i)?)? != y._lb_to_c(y._lower_bounds(i)?)?)
          then
            return false
          end
        end
        return true
      else
        return false
      end
    else
      false
    end

  fun box ne(y: HashPartitions box): Bool =>
    """
    Implement eq for Equatable trait.
    """
    not eq(y)

  fun box string(): String iso^ =>
    """
    Implement string for Stringable trait.
    """
    let s: String iso = "".clone()

    try
      for i in _lower_bounds.keys() do
        s.append(_lb_to_c(_lower_bounds(i)?)? + "@" +
          _interval_sizes(i)?.string() + ",")
      end
    else
      Fail()
    end
    consume s

  fun get_claimant(hash: U128): String ? =>
    var next_to_last_idx: USize = _lower_bounds.size() - 1
    var last_idx: USize = 0

    if hash > _lower_bounds(next_to_last_idx)? then
      return _lb_to_c(_lower_bounds(next_to_last_idx)?)?
    end

    // Binary search
    while true do
      let next_lower_bound = _lower_bounds(last_idx)?

      if hash >= next_lower_bound then
        if hash < _lower_bounds(last_idx + 1)? then
          return _lb_to_c(next_lower_bound)?
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
    _lb_to_c.values()

  fun _get_interval_size_sums(): Map[String,U128] =>
    let interval_sums: Map[String,U128] = interval_sums.create()

    try
      for c in _lb_to_c.values() do
        interval_sums(c) = 0
      end

      for i in Range[USize](0, _lower_bounds.size()) do
        let c = _lb_to_c(_lower_bounds(i)?)?
        interval_sums(c) = interval_sums(c)? + _interval_sizes(i)?
      end
    else
      Fail()
    end
    interval_sums

  fun get_sizes(): Array[(String, U128)] =>
    let s: Array[(String, U128)] = s.create()

    try 
      for i in Range[USize](0, _lower_bounds.size()) do
        let c = _lb_to_c(_lower_bounds(i)?)?
        s.push((c, _interval_sizes(i)?))
      end
    else
      Fail()
    end
    s

  fun get_weights_unit_interval(): Map[String,F64] =>
    let ws: Map[String, F64] = ws.create()

    for (c, sum) in _get_interval_size_sums().pairs() do
      ws(c) = sum.f64() / U128.max_value().f64()
    end
    ws

  fun get_weights_normalized(decimal_digits: USize = 2): Map[String,F64] =>
    let ws: Map[String, F64] = ws.create()
    var min_weight = F64.max_value()
    let weights = get_weights_unit_interval()

    for (_, weight) in weights.pairs() do
      min_weight = min_weight.min(weight)
    end
    if min_weight == 0 then
      Fail()
    end
    for (node, weight) in weights.pairs() do
      ws(node) = RoundF64(weight.f64() / min_weight, decimal_digits)
    end
    ws

  fun pretty_print() =>
    for (n, w) in _normalize_for_pp().values() do
      @printf[I32]("node %10s relative-size %.4f\n".cstring(), n.cstring(), w)
    end

  fun _normalize_for_pp(decimal_digits: USize = 2): Array[(String, F64)] =>
    var min_size: U128 = U128.max_value()
    let ns: Array[(String, F64)] = ns.create()

    try
      for i in Range[USize](0, _interval_sizes.size()) do
        min_size = min_size.min(_interval_sizes(i)?)
      end
      if min_size == 0 then
        Fail()
      end

      for i in Range[USize](0, _interval_sizes.size()) do
        let w = RoundF64(_interval_sizes(i)?.f64() / min_size.f64(), decimal_digits)
        ns.push((_lb_to_c(_lower_bounds(i)?)?, w))
      end
    else
      Fail()
    end
    ns

  fun _adjust_weights(new_weights: Array[(String, F64)] val,
    decimal_digits: USize = 2): HashPartitions
   =>
    //// Figure out what claimants have been removed.

    let current_weights = get_weights_normalized(decimal_digits)
    var current_cs: Set[String] = current_cs.create()
    let current_sizes_m = _get_interval_size_sums()
    var new_cs: Set[String] = new_cs.create()
    let new_weights_m: Map[String, F64] = new_weights_m.create()
    let new_sizes_m: Map[String, U128] = new_sizes_m.create()
    var sum_new_weights: F64 = 0.0

    for (c, w) in get_weights_normalized().pairs() do
      current_cs = current_cs.add(c)
    end
    for (c, w) in new_weights.values() do
      new_cs = new_cs.add(c)
      let w' = RoundF64(w, decimal_digits)
      sum_new_weights = sum_new_weights + w'
      new_weights_m(c) = w'
      if not current_sizes_m.contains(c) then
        current_sizes_m(c) = 0
      end
    end
    let removed_cs = current_cs.without(new_cs)

    //// Assign weights of zero to claimants not in the new list
    for c in removed_cs.values() do
      new_weights_m(c) = 0.0
    end

    //// Calculate the interval slices that need to be redistributed
    let size_add: Map[String,U128] = size_add.create()
    let size_sub: Map[String,U128] = size_sub.create()

    try
      for (c, w) in new_weights_m.pairs() do
        let new_size = if (sum_new_weights == 1.0) and (w == sum_new_weights) then
            U128.max_value() // Avoid overflow to 0!
          else
            U128.from[F64]((w / sum_new_weights) * U128.max_value().f64())
          end
        if new_size > current_sizes_m(c)? then
          size_add(c) = (new_size - current_sizes_m(c)?)
        elseif new_size < current_sizes_m(c)? then
          size_sub(c) = (current_sizes_m(c)? - new_size)
        else
          None
        end
      end
    else
      Fail()
    end

    //// Get the current map in Array[(Claimant,Size)] format, which
    //// is what create2() requires.

    let sizes1 = get_sizes()
    //// Process subtractions first: use the claimant name ""
    //// for unclaimed intervals.
    let sizes2 = _process_subtractions(sizes1, size_sub)

    let sizes2b = _coalesce_adjacent_intervals(sizes2)
    //// Process additions next.
    let sizes3 = _process_additions(consume sizes2b, size_add, decimal_digits)

    //// Coalesce adjacent intervals to reduce the size of the map
    let sizes4 = _coalesce_adjacent_intervals(sizes3)

    //// Deal with a couple of edge cases
    let sizes5 = if sizes4.size() == 0 then
      Fail(); consume sizes4
    elseif sizes4.size() == 1 then
      // Either it's all unclaimed or all claimed or we have an error
      try
        (let c, let s) = sizes4(0)?
        let frac = (s.f64() / U128.max_value().f64())
        if RoundF64(frac, decimal_digits) != 1.0 then
          Fail()
        end
        if c == "" then
          // Entire interval is unclaimed, so return empty list instead.
          let empty: Array[(String, U128)] trn = recover empty.create() end
          consume empty
        else
          // Entire interval claimed by s, so leave it alone
          consume sizes4
        end
      else
        Fail()
        let empty: Array[(String, U128)] trn = recover empty.create() end
        consume empty
      end
    else
      consume sizes4
    end

    //// Done!
    HashPartitions.create_with_sizes(consume sizes5)

  fun _process_subtractions(old_sizes: Array[(String, U128)],
    size_sub: Map[String, U128]): Array[(String, U128)]
  =>
    let new_sizes: Array[(String, U128)] iso = recover new_sizes.create() end

    try
      for (c, s) in old_sizes.values() do
        if size_sub.contains(c) then
          let to_sub = size_sub(c)?

          if to_sub > 0 then
            if to_sub >= s then
              new_sizes.push(("", s))     // Unassign all of s
              size_sub(c) = to_sub - s
            else
              let remainder = s - to_sub  // Unassign some of s, keep remainder
              new_sizes.push((c, remainder))
              new_sizes.push(("", to_sub))
              size_sub(c) = 0
            end
          else
            // c has had enough subtracted from its overall total, keep this
            new_sizes.push((c, s)) // Assignment of s is unchanged
          end
        else
          new_sizes.push((c, s)) // Assignment of s is unchanged
        end
      end
    else
      Fail()
    end
    new_sizes
    
  fun _process_additions(old_sizes: Array[(String, U128)],
    size_add: Map[String, U128], decimal_digits: USize):
    Array[(String, U128)]
  =>
    let new_sizes: Array[(String, U128)] = new_sizes.create()
    let total_length = old_sizes.size()

    try
      for i in Range[USize](0, total_length) do
        (let c, let s) = old_sizes(i)?

        if c != "" then
          new_sizes.push((c, s)) // Assignment of s is unchanged
        else
          // Bind neighbors (or dummy values) on the left & right.
          (let left_c, let left_s) = if i > 0 then
            old_sizes(i - 1)?
          else
            ("", 0)
          end
          (let right_c, let right_s) = if i < (total_length - 1) then
            old_sizes(i + 1)?
          else
            ("", 0)
          end

          // Is there a neighbor on the left that needs extra?
          if (i > 0)
            and (left_c != "") and (size_add.contains(left_c))
            and (size_add(left_c)? > 0)
          then
            let to_add = size_add(left_c)?

            if to_add >= s then
              // Assign all of s to left. 
              new_sizes.push((left_c, s))
              size_add(left_c) = to_add - s
            else
              // Assign some of s, keep remainder unassigned.
              // Split s into 2, copy remaining old_sizes -> new_sizes,
              // then recurse.
              let remainder = s - to_add
              new_sizes.push((left_c, to_add)) // Keep on left side
              new_sizes.push(("", remainder))
              new_sizes.reserve(total_length + 1)
              old_sizes.copy_to(new_sizes, i + 1, i + 2,
                total_length - (i + 1))
              size_add(left_c) = 0
              return _process_additions(new_sizes, size_add, decimal_digits)
            end
          // Is there a neighbor on the right that needs extra?
          elseif (i < (total_length - 1))
            and(right_c != "") and (size_add.contains(right_c))
            and (size_add(right_c)? > 0)
          then
            let to_add = size_add(right_c)?

            if to_add >= s then
              // Assign all of s to right.
              new_sizes.push((right_c, s))
              size_add(right_c) = to_add - s
            else
              // Assign some of s, keep remainding unassigned.
              // Split s into 2, copy remaining old_sizes -> new_sizes,
              // then recurse.
              let remainder = s - to_add
              new_sizes.push(("", remainder))
              new_sizes.push((right_c, to_add)) // Keep on right side
              new_sizes.reserve(total_length + 1)
              old_sizes.copy_to(new_sizes, i + 1, i + 2,
                total_length - (i + 1))
              size_add(right_c) = 0
              return _process_additions(new_sizes, size_add, decimal_digits)
            end
          // Neither neighbor is suitable, so choose another claimant
          else
            let smallest_c = _find_smallest_nonzero_size_to_add(size_add,
              decimal_digits, s)
            if (smallest_c == "") then
              None // Don't add anything to new_sizes
            else
              new_sizes.push((c, s)) // This is the unassigned size
              // Zero size is illegal in the final result, but it will be
              // removed when we recurse, or it will be removed by final
              // neighbor coalescing.
              new_sizes.push((smallest_c, 0))
              new_sizes.reserve(total_length + 1)
              old_sizes.copy_to(new_sizes, i + 1, i + 2,
                total_length - (i + 1))
              return _process_additions(new_sizes, size_add, decimal_digits)
            end
          end
        end // if c != ...
      end //for i ...
    else
      Fail()
    end
    new_sizes

  fun _find_smallest_nonzero_size_to_add(size_add: Map[String,U128],
    decimal_digits: USize, vestige_size: U128): String
  =>
    var smallest_c = ""
    var smallest_s = U128.max_value()

    for (c, s) in size_add.pairs() do
      if (s > 0) and (s < smallest_s) then
        smallest_c = c
        smallest_s = s
      end
    end
    if smallest_c != "" then
      smallest_c
    else
      let vestige_perc = (vestige_size.f64() / U128.max_value().f64()) * 100.0
      let vestige_rounded = RoundF64(vestige_perc, decimal_digits + 2)
      if not ((vestige_rounded == 0.0) or (vestige_rounded == 100.0)) then
        Fail()
      end
      ""
    end


  fun _coalesce_adjacent_intervals(old_sizes: Array[(String, U128)]):
    Array[(String, U128)] trn^
  =>
    let new_sizes: Array[(String, U128)] trn = recover new_sizes.create() end

    if old_sizes.size() == 0 then
      return recover [("", U128.max_value())] end
    end
    try
      (let first_c, let first_s) = old_sizes.shift()?
      if old_sizes.size() == 0 then
        new_sizes.push((first_c, first_s))
        consume new_sizes
      else
        (let next_c, let next_s) = old_sizes.shift()?
        _coalesce(first_c, first_s, next_c, next_s, old_sizes, consume new_sizes)
      end
    else
      recover Array[(String, U128)]() end
    end

  fun _coalesce(last_c: String, last_s: U128, head_c: String, head_s: U128,
    tail: Array[(String, U128)], new_sizes: Array[(String, U128)] trn):
    Array[(String, U128)] trn^
  =>
    if tail.size() == 0 then
      if last_c == head_c then
        new_sizes.push((last_c, last_s + head_s))
      else
        new_sizes.push((last_c, last_s))
        new_sizes.push((head_c, head_s))
      end
      return consume new_sizes
    end
    try
      (let next_c, let next_s) = tail.shift()?
      if last_c == head_c then
        _coalesce(head_c, last_s + head_s, next_c, next_s, tail, consume new_sizes)
      else
        new_sizes.push((last_c, last_s))
        _coalesce(head_c, head_s, next_c, next_s, tail, consume new_sizes)
      end
    else
      Fail()
      recover Array[(String, U128)]() end
    end

primitive RoundF64
  fun apply(f: F64, decimal_digits: USize = 2): F64 =>
    let factor = F64(10).pow(decimal_digits.f64())

    ((f * factor) + 0.5).trunc() / factor
