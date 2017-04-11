use "collections"

// primitive MapHelpers[K, V]
//   fun forall(m: Map[K, V], pred: {(K, V): Bool}): Bool =>
//     for (k, v) in m.pairs() do
//       if not pred(k, v) then return false end
//     end
//     return true

//   fun some(m: Map[K, V], pred: {(K, V): Bool}): Bool =>
//     for (k, v) in m.pairs() do
//       if pred(k, v) then return true end
//     end
//     return false

primitive SetHelpers[V]
  fun forall(s: SetIs[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in s.values() do
      if not pred(v) then return false end
    end
    true

  fun some(s: SetIs[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in s.values() do
      if pred(v) then return true end
    end
    false

primitive ArrayHelpers[V]
  fun forall(arr: Array[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in arr.values() do
      if not pred(v) then return false end
    end
    true

  fun some(arr: Array[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in arr.values() do
      if pred(v) then return true end
    end
    false
