use "collections"
use "sendence/connemara"

actor _TestVectorTimestamp is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestGreaterThanLessThan)
    test(_TestGreaterThanEqualLessThanEqual)
    test(_TestComparability)
    test(_TestIsSubset)
    test(_TestMerging)

class iso _TestGreaterThanLessThan is UnitTest
  """
  Test that vector timestamps are called greater or less than in
  under the correct conditions
  """
  fun name(): String =>
    "vector_ts/GreaterThanLessThan"

  fun ref apply(h: TestHelper) =>
    let v1_map: Map[String, U64] trn = recover Map[String, U64] end
    v1_map("w1") = 0
    v1_map("w2") = 2
    v1_map("w3") = 1
    let v1 = VectorTimestamp("w1", consume v1_map)

    let v2_map: Map[String, U64] trn = recover Map[String, U64] end
    v2_map("w1") = 0
    v2_map("w2") = 3
    v2_map("w3") = 1
    let v2 = VectorTimestamp("w2", consume v2_map)

    let v3_map: Map[String, U64] trn = recover Map[String, U64] end
    v3_map("w1") = 0
    v3_map("w2") = 1
    v3_map("w3") = 1
    let v3 = VectorTimestamp("w3", consume v3_map)

    let v4_map: Map[String, U64] trn = recover Map[String, U64] end
    v4_map("w1") = 0
    v4_map("w2") = 2
    v4_map("w3") = 0
    let v4 = VectorTimestamp("w3", consume v4_map)

    h.assert_eq[Bool](true, v2 > v1)
    h.assert_eq[Bool](true, v2.inc() > v1)
    h.assert_eq[Bool](true, not (v2 > v1.inc()))
    h.assert_eq[Bool](true, v1 > v3)
    h.assert_eq[Bool](true, v1.inc() > v3)
    h.assert_eq[Bool](true, not (v1.inc() > v3.inc()))
    h.assert_eq[Bool](true, v1.inc() > v4.inc())
    h.assert_eq[Bool](true, v2 > v3)
    h.assert_eq[Bool](true, v2 > v4)
    h.assert_eq[Bool](false, v4 > v2)
    h.assert_eq[Bool](false, v4 > v3)
    h.assert_eq[Bool](false, v3 > v4)

    h.assert_eq[Bool](true, v1 < v2)
    h.assert_eq[Bool](true, v3 < v1)
    h.assert_eq[Bool](true, v3 < v2)
    h.assert_eq[Bool](true, v4 < v2)
    h.assert_eq[Bool](false, v2 < v4)
    h.assert_eq[Bool](false, v3 < v4)
    h.assert_eq[Bool](false, v4 < v3)

class iso _TestGreaterThanEqualLessThanEqual is UnitTest
  """
  Test that vector timestamps are called >= or <= under the correct
  conditions
  """
  fun name(): String =>
    "vector_ts/GreaterThanEqualLessThanEqual"

  fun ref apply(h: TestHelper) =>
    let v1_map: Map[String, U64] trn = recover Map[String, U64] end
    v1_map("w1") = 0
    v1_map("w2") = 2
    v1_map("w3") = 1
    let v1 = VectorTimestamp("w1", consume v1_map)

    let v2_map: Map[String, U64] trn = recover Map[String, U64] end
    v2_map("w1") = 0
    v2_map("w2") = 3
    v2_map("w3") = 1
    let v2 = VectorTimestamp("w1", consume v2_map)

    let v3_map: Map[String, U64] trn = recover Map[String, U64] end
    v3_map("w1") = 0
    v3_map("w2") = 1
    v3_map("w3") = 1
    let v3 = VectorTimestamp("w1", consume v3_map)

    let v4_map: Map[String, U64] trn = recover Map[String, U64] end
    v4_map("w1") = 0
    v4_map("w2") = 2
    v4_map("w3") = 0
    let v4 = VectorTimestamp("w1", consume v4_map)

    let v5_map: Map[String, U64] trn = recover Map[String, U64] end
    v5_map("w1") = 0
    v5_map("w2") = 3
    v5_map("w3") = 1
    let v5 = VectorTimestamp("w1", consume v5_map)

    let v6_map: Map[String, U64] trn = recover Map[String, U64] end
    v6_map("w1") = 0
    v6_map("w2") = 2
    v6_map("w3") = 0
    let v6 = VectorTimestamp("w1", consume v6_map)

    h.assert_eq[Bool](true, v2 >= v1)
    h.assert_eq[Bool](true, v1 >= v3)
    h.assert_eq[Bool](true, v2 >= v3)
    h.assert_eq[Bool](true, v2 >= v4)
    h.assert_eq[Bool](false, v4 >= v2)
    h.assert_eq[Bool](false, v4 >= v3)
    h.assert_eq[Bool](false, v3 >= v4)

    h.assert_eq[Bool](true, v1 <= v2)
    h.assert_eq[Bool](true, v3 <= v1)
    h.assert_eq[Bool](true, v3 <= v2)
    h.assert_eq[Bool](true, v4 <= v2)
    h.assert_eq[Bool](false, v2 <= v4)
    h.assert_eq[Bool](false, v3 <= v4)
    h.assert_eq[Bool](false, v4 <= v3)

    h.assert_eq[Bool](true, v2 >= v5)
    h.assert_eq[Bool](true, v5 <= v2)
    h.assert_eq[Bool](true, not (v2 >= v5.inc()))
    h.assert_eq[Bool](true, not (v5.inc() <= v2))

    h.assert_eq[Bool](true, v4 >= v6)
    h.assert_eq[Bool](true, v6 <= v4)
    h.assert_eq[Bool](true, not (v4 >= v6.inc()))
    h.assert_eq[Bool](true, not (v6.inc() <= v4))

class iso _TestComparability is UnitTest
  """
  Test that vector timestamps are called comparable under the correct
  conditions
  """
  fun name(): String =>
    "vector_ts/Comparability"

  fun ref apply(h: TestHelper) =>
    let v1_map: Map[String, U64] trn = recover Map[String, U64] end
    v1_map("w1") = 0
    v1_map("w2") = 2
    v1_map("w3") = 1
    let v1 = VectorTimestamp("w1", consume v1_map)

    let v2_map: Map[String, U64] trn = recover Map[String, U64] end
    v2_map("w1") = 0
    v2_map("w2") = 3
    v2_map("w3") = 1
    let v2 = VectorTimestamp("w2", consume v2_map)

    let v3_map: Map[String, U64] trn = recover Map[String, U64] end
    v3_map("w1") = 1
    v3_map("w2") = 2
    v3_map("w3") = 2
    let v3 = VectorTimestamp("w3", consume v3_map)

    let v4_map: Map[String, U64] trn = recover Map[String, U64] end
    v4_map("w1") = 0
    v4_map("w2") = 3
    v4_map("w3") = 0
    let v4 = VectorTimestamp("w3", consume v4_map)

    h.assert_eq[Bool](true, v1.is_comparable(v1))
    h.assert_eq[Bool](true, v1.is_comparable(v2))
    h.assert_eq[Bool](true, v1.is_comparable(v3))
    h.assert_eq[Bool](true, not v1.is_comparable(v4))

    h.assert_eq[Bool](true, v2.is_comparable(v1))
    h.assert_eq[Bool](true, v2.is_comparable(v2))
    h.assert_eq[Bool](true, not v2.is_comparable(v3))
    h.assert_eq[Bool](true, v2.is_comparable(v4))

    h.assert_eq[Bool](true, v3.is_comparable(v1))
    h.assert_eq[Bool](true, not v3.is_comparable(v2))
    h.assert_eq[Bool](true, v3.is_comparable(v3))
    h.assert_eq[Bool](true, not v3.is_comparable(v4))

    h.assert_eq[Bool](true, not v4.is_comparable(v1))
    h.assert_eq[Bool](true, v4.is_comparable(v2))
    h.assert_eq[Bool](true, not v4.is_comparable(v3))
    h.assert_eq[Bool](true, v4.is_comparable(v4))

class iso _TestIsSubset is UnitTest
  """
  Test that vector timestamps are called subsets of each other under the
  correct conditions
  """
  fun name(): String =>
    "vector_ts/IsSubset"

  fun ref apply(h: TestHelper) =>
    let v1_map: Map[String, U64] trn = recover Map[String, U64] end
    v1_map("w1") = 0
    v1_map("w2") = 2
    let v1 = VectorTimestamp("w1", consume v1_map)

    let v2_map: Map[String, U64] trn = recover Map[String, U64] end
    v2_map("w1") = 0
    v2_map("w2") = 3
    v2_map("w3") = 1
    let v2 = VectorTimestamp("w1", consume v2_map)

    let v3_map: Map[String, U64] trn = recover Map[String, U64] end
    v3_map("w1") = 1
    v3_map("w2") = 2
    v3_map("w3") = 2
    v3_map("w4") = 3
    let v3 = VectorTimestamp("w1", consume v3_map)

    let v4_map: Map[String, U64] trn = recover Map[String, U64] end
    v4_map("w3") = 0
    v4_map("w4") = 3
    let v4 = VectorTimestamp("w4", consume v4_map)

    h.assert_eq[Bool](true, v1.is_subset_of(v1))
    h.assert_eq[Bool](true, v1.is_subset_of(v2))
    h.assert_eq[Bool](true, v1.is_subset_of(v3))
    h.assert_eq[Bool](true, not v1.is_subset_of(v4))

    h.assert_eq[Bool](true, not v2.is_subset_of(v1))
    h.assert_eq[Bool](true, v2.is_subset_of(v2))
    h.assert_eq[Bool](true, v2.is_subset_of(v3))
    h.assert_eq[Bool](true, not v2.is_subset_of(v4))

    h.assert_eq[Bool](true, not v3.is_subset_of(v1))
    h.assert_eq[Bool](true, not v3.is_subset_of(v2))
    h.assert_eq[Bool](true, v3.is_subset_of(v3))
    h.assert_eq[Bool](true, not v3.is_subset_of(v4))

    h.assert_eq[Bool](true, not v4.is_subset_of(v1))
    h.assert_eq[Bool](true, not v4.is_subset_of(v2))
    h.assert_eq[Bool](true, v4.is_subset_of(v3))
    h.assert_eq[Bool](true, v4.is_subset_of(v4))

    h.assert_eq[Bool](true, v1.merge(v4).is_subset_of(v3))
    h.assert_eq[Bool](true, v2.merge(v4).is_subset_of(v3))
    h.assert_eq[Bool](true, v3.is_subset_of(v1.merge(v4)))
    h.assert_eq[Bool](true, v3.is_subset_of(v2.merge(v4)))

class iso _TestMerging is UnitTest
  """
  Test that vector timestamps are merged correctly
  """
  fun name(): String =>
    "vector_ts/Merging"

  fun ref apply(h: TestHelper) =>
    var v1 = VectorTimestamp("w1").inc()
    var v2 = VectorTimestamp("w2").inc()
    var v3 = VectorTimestamp("w3").inc()
    var v4 = VectorTimestamp("w4").inc()

    h.assert_eq[Bool](true, v1.is_comparable(v1))
    h.assert_eq[Bool](true, not v1.is_comparable(v2))
    h.assert_eq[Bool](true, not v1.is_comparable(v3))
    h.assert_eq[Bool](true, not v1.is_comparable(v4))

    h.assert_eq[Bool](true, not v2.is_subset_of(v1))

    v1 = v1.merge(v2).inc()
    v3 = v3.merge(v4).inc()

    v1.print()
    v2.print()

    h.assert_eq[Bool](true, v2.is_subset_of(v1))
    h.assert_eq[Bool](true, v4.is_subset_of(v3))
    h.assert_eq[Bool](true, v1.is_comparable(v2))
    h.assert_eq[Bool](true, v1 > v2)
    h.assert_eq[Bool](true, v2 < v1)
    h.assert_eq[Bool](true, v3 > v4)

    v4 = v4.merge(v1).inc()

    h.assert_eq[Bool](true, v4.is_comparable(v1))
    h.assert_eq[Bool](true, v4 > v1)
    h.assert_eq[Bool](true, v4 > v2)
    h.assert_eq[Bool](true, not v4.is_comparable(v3))
