/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "ponytest"
use "collections"
use "debug"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestQueue)
    test(_TestFixedQueue)

class iso _TestQueue is UnitTest
  fun name(): String => "queue/Queue"

  fun apply(h: TestHelper) ? =>
    let q1 = Queue[U64]
    h.assert_eq[USize](q1.size(), 0)
    h.assert_eq[USize](q1.space(), 2)

    q1.enqueue(0)?
    h.assert_eq[U64](q1.dequeue()?, 0)

    q1.enqueue(1)?
    q1.enqueue(2)?
    q1.enqueue(3)?
    q1.enqueue(4)?
    q1.enqueue(5)?
    h.assert_eq[USize](q1.size(), 5)
    h.assert_eq[U64](q1.dequeue()?, 1)
    q1.enqueue(6)?
    h.assert_eq[U64](q1.dequeue()?, 2)
    h.assert_eq[U64](q1.peek()?, 3)
    h.assert_eq[U64](q1(2)?, 5)
    h.assert_eq[USize](q1.size(), 4)
    q1.enqueue(7)?
    q1.enqueue(8)?
    q1.enqueue(9)?
    q1.enqueue(10)?
    h.assert_eq[USize](q1.size(), 8)
    h.assert_eq[Bool](q1.contains(1), false)
    h.assert_eq[Bool](q1.contains(3), true)
    h.assert_eq[Bool](q1.contains(8), true)
    h.assert_eq[Bool](q1.contains(11), false)

    var i: USize = 0
    for n in q1.values() do
      h.assert_eq[U64](q1(i)?, (i + 3).u64())
      i = i + 1
    end

    let q2 = Queue[USize]

    for j in Range(0, 20) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 64)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(20, 60) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 128)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue()?, j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 128)
    for j in Range(60, 80) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 128)

    i = 0
    for n in q2.values() do
      h.assert_eq[USize](q2(i)?, i + 50)
      i = i + 1
    end

    q2.enqueue(80)?
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 128)

    i = 0
    for n in q2.values() do
      h.assert_eq[USize](q2(i)?, i + 50)
      i = i + 1
    end

    i = 0
    for (idx, n) in q2.pairs() do
      h.assert_eq[USize](q2(idx)?, i + 50)
      h.assert_eq[USize](q2(idx)?, n)
      i = i + 1
    end

    for j in Range(50, 70) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    for j in Range(81, 128) do
      q2.enqueue(j)?
    end

    for j in Range(70, 110) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    for j in Range(128, 140) do
      q2.enqueue(j)?
    end

    for j in Range(110, 130) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    true

class iso _TestFixedQueue is UnitTest
  fun name(): String => "queue/FixedQueue"

  fun apply(h: TestHelper) ? =>
    let q1 = FixedQueue[U64](64)
    h.assert_eq[USize](q1.size(), 0)
    h.assert_eq[USize](q1.space(), 64)

    q1.enqueue(0)?
    h.assert_eq[U64](q1.dequeue()?, 0)

    q1.enqueue(1)?
    q1.enqueue(2)?
    q1.enqueue(3)?
    q1.enqueue(4)?
    q1.enqueue(5)?
    h.assert_eq[USize](q1.size(), 5)
    h.assert_eq[U64](q1.dequeue()?, 1)
    q1.enqueue(6)?
    h.assert_eq[U64](q1.dequeue()?, 2)
    h.assert_eq[U64](q1.peek()?, 3)
    h.assert_eq[U64](q1(2)?, 5)
    h.assert_eq[USize](q1.size(), 4)
    q1.enqueue(7)?
    q1.enqueue(8)?
    q1.enqueue(9)?
    q1.enqueue(10)?
    h.assert_eq[USize](q1.size(), 8)
    h.assert_eq[Bool](q1.contains(1), false)
    h.assert_eq[Bool](q1.contains(3), true)
    h.assert_eq[Bool](q1.contains(8), true)
    h.assert_eq[Bool](q1.contains(11), false)

    var i: USize = 0
    for n in Range(0, q1.size()) do
      h.assert_eq[U64](q1(i)?, (i + 3).u64())
      i = i + 1
    end

    let q2 = FixedQueue[USize](64)

    for j in Range(0, 20) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 64)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(20, 60) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue()?, j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(60, 80) do
      q2.enqueue(j)?
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i)?, i + 50)
      i = (i + 1) % q2.size()
    end

    q2.enqueue(80)?
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 64)

    i = 0
    for n in Range(0, q2.size()) do
      h.assert_eq[USize](q2(i)?, i + 50)
      i = i + 1
    end

    for j in Range(50, 70) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    for j in Range(81, 128) do
      q2.enqueue(j)?
    end

    for j in Range(70, 110) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    for j in Range(128, 140) do
      q2.enqueue(j)?
    end

    h.assert_eq[Bool](q2.contains(129), true)
    h.assert_eq[Bool](q2.contains(150), false)

    for j in Range(110, 130) do
      h.assert_eq[USize](q2.dequeue()?, j)
    end

    h.assert_error({()? =>
      let q3 = FixedQueue[U64](1)
      q3.enqueue(1)?
      q3.enqueue(2)?
    })

    true
