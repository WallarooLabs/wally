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
    test(_TestContainerQueue)

class Count
  var _name: String
  var _count: USize

  new ref create(d: (String, USize)) =>
    _name = d._1
    _count = d._2

  fun ref write(d: (String, USize)) =>
    _name = d._1
    _count = d._2

  fun ref read(): (String, USize) =>
    (_name, _count)

class CountBuilder
  fun apply(d: (String, USize)): Count =>
    Count(d)

class iso _TestContainerQueue is UnitTest
  fun name(): String => "container_queue/ContainerQueue"

  fun apply(h: TestHelper) ? =>
    let q1 = ContainerQueue[(String, USize), Count](CountBuilder)
    h.assert_eq[USize](q1.size(), 0)
    h.assert_eq[USize](q1.space(), 2)

    q1.enqueue(("0", 0))
    let next = q1.dequeue()
    h.assert_eq[String](next._1, "0")
    h.assert_eq[USize](next._2, 0)

    q1.enqueue(("1", 1))
    q1.enqueue(("2", 2))
    q1.enqueue(("3", 3))
    q1.enqueue(("4", 4))
    q1.enqueue(("5", 5))
    h.assert_eq[USize](q1.size(), 5)
    h.assert_eq[USize](q1.dequeue()._2, 1)
    q1.enqueue(("6", 6))
    h.assert_eq[USize](q1.dequeue()._2, 2)
    h.assert_eq[USize](q1.peek()._2, 3)
    h.assert_eq[USize](q1(2)._2, 5)
    h.assert_eq[USize](q1.size(), 4)
    q1.enqueue(("7", 7))
    q1.enqueue(("8", 8))
    q1.enqueue(("9", 9))
    q1.enqueue(("10", 10))
    h.assert_eq[USize](q1.size(), 8)
    // h.assert_eq[Bool](q1.contains(1), false)
    // h.assert_eq[Bool](q1.contains(3), true)
    // h.assert_eq[Bool](q1.contains(8), true)
    // h.assert_eq[Bool](q1.contains(11), false)

    // var i: USize = 0
    // for n in q1.values() do
    //   h.assert_eq[USize](q1(i)._2, i + 3)
    //   i = i + 1
    // end

    let q2 = ContainerQueue[(String, USize), Count](CountBuilder)

    for j in Range(0, 20) do
      q2.enqueue((j.string(), j))
    end
    h.assert_eq[USize](q2.size(), 20)
    h.assert_eq[USize](q2.space(), 64)

    for j in Range(0, 15) do
      h.assert_eq[USize](q2.dequeue()._2, j)
    end
    h.assert_eq[USize](q2.size(), 5)
    h.assert_eq[USize](q2.space(), 64)
    for j in Range(20, 60) do
      q2.enqueue((j.string(), j))
    end
    h.assert_eq[USize](q2.size(), 45)
    h.assert_eq[USize](q2.space(), 128)
    for j in Range(0, 35) do
      h.assert_eq[USize](q2.dequeue()._2, j + 15)
    end
    h.assert_eq[USize](q2.size(), 10)
    h.assert_eq[USize](q2.space(), 128)
    for j in Range(60, 80) do
      q2.enqueue((j.string(), j))
    end
    h.assert_eq[USize](q2.size(), 30)
    h.assert_eq[USize](q2.space(), 128)

    // i = 0
    // for n in q2.values() do
    //   h.assert_eq[USize](q2(i)._2, i + 50)
    //   i = i + 1
    // end

    q2.enqueue(("80", 80))
    h.assert_eq[USize](q2.size(), 31)
    h.assert_eq[USize](q2.space(), 128)

    // i = 0
    // for n in q2.values() do
    //   h.assert_eq[USize](q2(i)._2, i + 50)
    //   i = i + 1
    // end

    // i = 0
    // for (idx, n) in q2.pairs() do
    //   h.assert_eq[USize](q2(idx)._2, i + 50)
    //   h.assert_eq[String](q2(idx)._1, n._1)
    //   h.assert_eq[USize](q2(idx)._2, n._2)
    //   i = i + 1
    // end

    for j in Range(50, 70) do
      h.assert_eq[USize](q2.dequeue()._2, j)
    end

    for j in Range(81, 128) do
      q2.enqueue((j.string(), j))
    end

    for j in Range(70, 110) do
      h.assert_eq[USize](q2.dequeue()._2, j)
    end

    for j in Range(128, 140) do
      q2.enqueue((j.string(), j))
    end

    for j in Range(110, 130) do
      h.assert_eq[USize](q2.dequeue()._2, j)
    end

    true
