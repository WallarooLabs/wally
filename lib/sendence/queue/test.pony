use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestQueue)

class iso _TestQueue is UnitTest
  fun name(): String => "sendence:Queue"

  fun apply(h: TestHelper) ? =>
    let q1 = Queue[U64]
    h.assert_eq[USize](q1.size(), 0)

    q1.enqueue(1)
    q1.enqueue(2)
    q1.enqueue(3)
    q1.enqueue(4)
    q1.enqueue(5)
    h.assert_eq[USize](q1.size(), 5)
    h.assert_eq[U64](q1.dequeue(), 1)
    q1.enqueue(6)
    h.assert_eq[U64](q1.dequeue(), 2)
    h.assert_eq[U64](q1.peek(), 3)
    h.assert_eq[U64](q1(2), 5)
    h.assert_eq[USize](q1.size(), 4)
    q1.enqueue(7)
    q1.enqueue(8)
    q1.enqueue(9)
    q1.enqueue(10)
    h.assert_eq[USize](q1.size(), 8)
    h.assert_eq[Bool](q1.contains(1), false)
    h.assert_eq[Bool](q1.contains(3), true)
    h.assert_eq[Bool](q1.contains(8), true)
    h.assert_eq[Bool](q1.contains(11), false)

    var i: USize = 0
    for n in q1.values() do
      h.assert_eq[U64](q1(i), (i + 3).u64())
      i = i + 1
    end


    let q2 = Queue[USize]

    for j in Range(0, 20) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 20)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue(), j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 20)
    for j in Range(20, 60) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 60)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue(), j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 60)
    for j in Range(60, 80) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 60)

    i = 0
    for n in q2.values() do
      h.assert_eq[USize](q2(i), i + 50)
      i = i + 1
    end

    q2.enqueue(80)
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 81)

    i = 0
    for n in q2.values() do
      h.assert_eq[USize](q2(i), i + 50)
      i = i + 1
    end

    i = 0
    for (idx, n) in q2.pairs() do
      h.assert_eq[USize](q2(idx), i + 50)
      h.assert_eq[USize](q2(idx), n)
      i = i + 1
    end

    true
