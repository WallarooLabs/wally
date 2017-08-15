use "collections"
use "random"
use "time"

class EnhancedRandom
  let _rand: Random
  let _indices: Array[USize] = Array[USize]

  new create(seed: U64 = Time.micros()) =>
    // TODO: Bring back using MT when we figure out
    // embed serialization issue
    // _rand = MT(seed)
    _rand = MT2(seed)

  fun ref int(n: U64): U64 => _rand.int(n)

  fun ref real(): F64 => _rand.real()

  fun ref u64(): U64 => _rand.next()

  fun ref flip(): U64 => _rand.int(2)

  fun ref roll(dice: I32, sides: I32): I32 =>
    var result: I32 = 0
    for i in Range[I32](0, dice) do
      result = result + i32_between(1, sides)
    end
    result

  fun ref test_odds(odds: F64): Bool =>
    odds > real()

  fun ref i32_between(low: I32, high: I32): I32 =>
    let r = (_rand.int((high.u64() + 1) - low.u64()) and 0x0000FFFF).i32()
    let value = r + low
    value

  fun ref usize_between(low: USize, high: USize): USize =>
    let r = (_rand.int((high.u64() + 1) - low.u64())).usize()
    let value = r + low
    value

  fun ref f64_between(low: F64, high: F64): F64 =>
    let r = (real() * (high - low))
    r + low

  fun ref pick[V: Any val](a: box->Array[V]): V ? =>
    let idx = (_rand.int(a.size().u64())).usize()
    a(idx)

  fun ref pick_ref[V: Any ref](a: Array[V]): V ? =>
    let idx = (_rand.int(a.size().u64())).usize()
    a(idx)

  fun ref pick_k_items[V: Any val](k: USize, a: Array[V] val):
    Array[V] val ?
  =>
    let a_size = a.size()
    if k > a_size then error end
    let idxs = SetIs[USize]
    while idxs.size() < k do
      idxs.set(usize_between(0, a_size - 1))
    end
    let result = recover trn Array[V] end
    for i in idxs.values() do
      result.push(a(i))
    end
    consume result

  fun ref pick_subset[V: Any val](a: Array[V] val): Array[V] val ? =>
    let k = usize_between(1, a.size())
    pick_k_items[V](k, a)

  fun ref shuffle_array[V](a: box->Array[V]): box->Array[V] ? =>
    let size = a.size()
    _indices.clear()
    for i in Range(0, size) do
      _indices.push(i)
    end
    for (i, value) in _indices.pairs() do
      let r = usize_between(i + 1, size - 1)
      _indices(i) = _indices(r)
    end
    a.permute(_indices.values())
    a
