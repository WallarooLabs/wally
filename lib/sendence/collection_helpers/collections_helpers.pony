use "collections"

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
