use "ponytest"
use "collections"
use "debug"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestWeighted)

class iso _TestWeighted is UnitTest
  fun name(): String => "weighted/Weighted"

  fun apply(h: TestHelper) ? =>
    let items: Array[(USize, USize)] trn = recover Array[(USize, USize)] end
    items.push((0, 1000))
    items.push((1, 150))
    items.push((2, 40))
    items.push((3, 39))
    items.push((4, 38))
    items.push((5, 37))
    items.push((6, 6))
    items.push((7, 5))
    items.push((8, 4))
    items.push((9, 3))
    items.push((10, 1))
    let results = Weighted[USize](consume items, 3)
    h.assert_eq[USize](results(0).size(), 1)
    h.assert_eq[USize](results(1).size(), 4)
    h.assert_eq[USize](results(2).size(), 6)

    h.assert_eq[USize](results(0)(0), 0)
    h.assert_eq[USize](results(1)(0), 1)
    h.assert_eq[USize](results(1)(1), 6)
    h.assert_eq[USize](results(1)(2), 8)
    h.assert_eq[USize](results(1)(3), 10)
    h.assert_eq[USize](results(2)(0), 2)
    h.assert_eq[USize](results(2)(1), 3)
    h.assert_eq[USize](results(2)(2), 4)
    h.assert_eq[USize](results(2)(3), 5)
    h.assert_eq[USize](results(2)(4), 7)
    h.assert_eq[USize](results(2)(5), 9)

    true
