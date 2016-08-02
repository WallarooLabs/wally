use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
    test(_TestPowersOf2Histogram)

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
