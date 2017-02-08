use "ponytest"
use "collections"
use "debug"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestFixedQueue)
    test(_TestNoneFixedQueue)

class iso _TestFixedQueue is UnitTest
  fun name(): String => "sendence:FixedQueue"

  fun apply(h: TestHelper) ? =>
    let q1 = FixedQueue[U64](64)
    h.assert_eq[USize](q1.size(), 0)
    h.assert_eq[USize](q1.space(), 64)

    q1.enqueue(0)
    h.assert_eq[U64](q1.dequeue(), 0)

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
    for n in Range(0, q1.size()) do
      h.assert_eq[U64](q1(i), (i + 3).u64())
      i = i + 1
    end

    let q2 = FixedQueue[USize](64)

    for j in Range(0, 20) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 64)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue(), j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(20, 60) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue(), j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(60, 80) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i), i + 50)
      i = (i + 1) % q2.size()
    end

    q2.enqueue(80)
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i), i + 50)
      i = i + 1
    end

    for j in Range(50, 70) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    for j in Range(81, 128) do
      q2.enqueue(j)
    end

    for j in Range(70, 110) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    for j in Range(128, 140) do
      q2.enqueue(j)
    end

    h.assert_eq[Bool](q2.contains(129), true)
    h.assert_eq[Bool](q2.contains(150), false)

    for j in Range(110, 130) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    h.assert_error({()? =>
      let q3 = FixedQueue[U64](1)
      q3.enqueue(1)
      q3.enqueue(2)
    })

    true

class iso _TestNoneFixedQueue is UnitTest
  fun name(): String => "sendence:NoneFixedQueue"

  fun apply(h: TestHelper) ? =>
    let q1 = NoneFixedQueue[U64](64)
    h.assert_eq[USize](q1.size(), 0)
    h.assert_eq[USize](q1.space(), 64)

    q1.enqueue(0)
    h.assert_eq[U64](q1.dequeue(), 0)

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
    // h.assert_eq[Bool](q1.contains(1), false)
    // h.assert_eq[Bool](q1.contains(3), true)
    // h.assert_eq[Bool](q1.contains(8), true)
    // h.assert_eq[Bool](q1.contains(11), false)

    var i: USize = 0
    for n in Range(0, q1.size()) do
      h.assert_eq[U64](q1(i), (i + 3).u64())
      i = i + 1
    end

    let q2 = NoneFixedQueue[USize](64)

    for j in Range(0, 20) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 64)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue(), j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(20, 60) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue(), j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(60, 80) do
      q2.enqueue(j)
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i), i + 50)
      i = (i + 1) % q2.size()
    end

    q2.enqueue(80)
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i), i + 50)
      i = i + 1
    end

    for j in Range(50, 70) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    for j in Range(81, 128) do
      q2.enqueue(j)
    end

    for j in Range(70, 110) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    for j in Range(128, 140) do
      q2.enqueue(j)
    end

    // h.assert_eq[Bool](q2.contains(129), true)
    // h.assert_eq[Bool](q2.contains(150), false)

    for j in Range(110, 130) do
      h.assert_eq[USize](q2.dequeue(), j)
    end

    h.assert_error({()? =>
      let q3 = NoneFixedQueue[U64](1)
      q3.enqueue(1)
      q3.enqueue(2)
    })

    true

