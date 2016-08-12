use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
    test(_TestPowersOf2Histogram)
    test(_TestPowersOf2HistogramMinMax)

class iso _TestPowersOf2Histogram is UnitTest
  fun name(): String => "sendence:PowersOf2Histogram"

  fun apply(h: TestHelper) ? =>
    let p = PowersOf2Histogram
    for u in Range[U64](1,1024*1024, 1) do
      p(u)
    end
    h.assert_eq[U64](p.get(p.get_idx(512)), 512)
    let p' = PowersOf2Histogram
    p'(512)
    h.assert_eq[U64](p'.get(p'.get_idx(512)), 1)
    let p'' = p + p'
    h.assert_eq[U64](p''.get(p''.get_idx(512)), 513)
    let p''' = p - p'
    h.assert_eq[U64](p'''.get(p'''.get_idx(512)), 511)
    true

class iso _TestPowersOf2HistogramMinMax is UnitTest
  fun name(): String => "sendence:PowersOf2HistogramMinMax"

  fun apply(h: TestHelper) ? =>
    let p = PowersOf2Histogram
    p.update(5, 1)
    h.assert_eq[U64](p.max(), U64(1) << 5)
    h.assert_eq[U64](p.min(), U64(1) << 4)
    for u in Range[U64](1,1024*1024, 1) do
      p(u)
    end
    h.assert_eq[U64](p.min(), 1)
    h.assert_eq[U64](p.max(), 1048575)
    p(1048576)
    h.assert_eq[U64](p.max(), 1048576)
    p.update(21, 3)
    h.assert_eq[U64](p.min(), 1)
    h.assert_eq[U64](p.max(), U64(1) << 21)
    true
