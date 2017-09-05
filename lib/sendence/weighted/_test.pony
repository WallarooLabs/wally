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

use "sendence/connemara"
use "collections"
use "debug"

actor Main is TestList
  new create(env: Env) => Connemara(env, this)

  new make() => None

  fun tag tests(test: Connemara) =>
    test(_TestWeighted)

class iso _TestWeighted is UnitTest
  fun name(): String => "weighted/Weighted"

  fun apply(h: TestHelper) ? =>
    let items = recover trn Array[(USize, USize)] end
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
