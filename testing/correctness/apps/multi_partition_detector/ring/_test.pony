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

use "collections"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestRing)
    test(_TestClone)
    test(_TestFromArray)
    test(_TestToArray)
    test(_TestString)
    test(_TestKeys)
    test(_TestValues)
    test(_TestPairs)

class iso _TestRing is UnitTest
  fun name(): String => "ring/Ring"

  fun apply(h: TestHelper) ? =>
    let size: USize = 5
    let ring = Ring[U64](size)
    for x in Range[U64](0,3) do
      ring.push(x)
    end

    h.assert_eq[USize](3, ring.size())
    h.assert_eq[USize](3, ring.count())
    h.assert_eq[U64](2, ring(0)?)
    h.assert_eq[U64](1, ring(1)?)
    h.assert_eq[U64](0, ring(2)?)

    let large_ring = Ring[U64](size)
    for x in Range[U64](0, 4) do
      large_ring.push(x)
    end
    h.assert_eq[U64](3, large_ring(0)?)
    h.assert_eq[U64](2, large_ring(1)?)
    h.assert_eq[U64](1, large_ring(2)?)
    h.assert_eq[U64](0, large_ring(3)?)
    large_ring.push(4)
    h.assert_eq[U64](4, large_ring(0)?)
    h.assert_eq[U64](3, large_ring(1)?)
    h.assert_eq[U64](2, large_ring(2)?)
    h.assert_eq[U64](1, large_ring(3)?)
    large_ring.push(5)
    large_ring.push(6)
    large_ring.push(7)
    large_ring.push(8)
    h.assert_eq[U64](8, large_ring(0)?)
    h.assert_eq[U64](7, large_ring(1)?)
    h.assert_eq[U64](6, large_ring(2)?)
    h.assert_eq[U64](5, large_ring(3)?)
    large_ring.push(9)
    h.assert_eq[USize](size, large_ring.size())
    h.assert_eq[USize](10, large_ring.count())
    h.assert_eq[U64](9, large_ring(0)?)
    h.assert_eq[U64](8, large_ring(1)?)
    h.assert_eq[U64](7, large_ring(2)?)
    h.assert_eq[U64](6, large_ring(3)?)
    h.assert_eq[U64](5, large_ring(4)?)

class iso _TestClone is UnitTest
  fun name(): String => "ring/Clone"

  fun apply(h: TestHelper) ? =>
    let r = Ring[U64](4)
    for x in Range[U64](0,5) do
      r.push(x)
    end
    let r' = r.clone()
    for x in Range[USize](0,4) do
      h.assert_eq[U64](r(x)?, r'(x)?)
    end

class iso _TestFromArray is UnitTest
  fun name(): String => "ring/FromArray"

  fun apply(h: TestHelper) ? =>
    let array: Array[U64] iso = recover [5; 6; 7; 8] end
    let size: USize = 4
    let count: USize = 8
    let ring = Ring[U64].from_array(consume array, size, count)

    h.assert_eq[USize](count, ring.count())
    h.assert_eq[USize](size, ring.size())
    h.assert_eq[U64](8, ring(0)?)
    h.assert_eq[U64](7, ring(1)?)
    h.assert_eq[U64](6, ring(2)?)
    h.assert_eq[U64](5, ring(3)?)

    ring.push(9)
    h.assert_eq[U64](9, ring(0)?)
    h.assert_eq[U64](6, ring(3)?)

    // test ring->raw->ring
    (let buf, let size', let count') = ring.raw()
    let new_ring = Ring[U64].from_array(consume buf, size', count')
    h.assert_true(new_ring.size() > 0)
    h.assert_eq[USize](size, new_ring.size())
    h.assert_eq[USize](new_ring.count(), new_ring.count())
    for x in Range[USize](0, new_ring.size()) do
      h.assert_eq[U64](ring(x)?, new_ring(x)?)
    end

    // test case where size < array.size() is given
    let size_lt_ring = Ring[U64].from_array(recover [1; 2; 3; 4] end, 3, 4)
    h.assert_eq[USize](4, size_lt_ring.size())

    // Test where size > array.size
    let size_gt_ring = Ring[U64].from_array(recover [1; 2] end, 4, 2)
    h.assert_eq[USize](2, size_gt_ring.size())
    size_gt_ring.push(3)
    size_gt_ring.push(4)
    h.assert_eq[USize](4, size_gt_ring.size())
    size_gt_ring.push(5)
    h.assert_eq[USize](4, size_gt_ring.size())

class iso _TestToArray is UnitTest
  fun name(): String => "ring/ToArray"

  fun apply(h: TestHelper) ? =>
    let array: Array[U64 val] val = recover [5; 6; 7; 8] end
    let size: USize = 4
    let ring = Ring[U64](size)
    for a in array.values() do
      ring.push(a)
    end

    let to_array = ring.to_array()
    h.assert_eq[U64](array(0)?, to_array(0)?)
    h.assert_eq[U64](array(1)?, to_array(1)?)
    h.assert_eq[U64](array(2)?, to_array(2)?)
    h.assert_eq[U64](array(3)?, to_array(3)?)

class iso _TestString is UnitTest
  fun name(): String => "ring/StringifyRing"

  fun apply(h: TestHelper) ? =>
    let size: USize = 4
    let ring = Ring[U64](size)
    for x in Range[U64](0,20) do
      ring.push(x)
    end

    h.assert_eq[USize](20, ring.count())
    let s = ring.string()?
    h.assert_eq[String]("[16,17,18,19]", s)

    let new_ring = Ring[String](size)
    new_ring.push("one")
    new_ring.push("two")
    new_ring.push("three")
    new_ring.push("four")
    new_ring.push("five")

    h.assert_eq[USize](5, new_ring.count())
    let new_s = new_ring.string(", ")?
    h.assert_eq[String]("[two, three, four, five]", new_s)

    let short_ring = Ring[U64](4)
    short_ring.push(1)
    short_ring.push(2)
    let short_s = short_ring.string(",", "x")?
    h.assert_eq[String]("[x,x,1,2]", short_s)

    let non_string_ring = Ring[MyNonStringable](4)
    for x in Range[U64](0,4) do
      non_string_ring.push(MyNonStringable(x, x*2))
    end
    let f': {(MyNonStringable): String} val = {(a: MyNonStringable): String
      =>
        "(".add(a.x.string()).add(",").add(a.y.string()).add(")")
    }
    let non_string_string = non_string_ring.string(where f = f')?
    h.assert_eq[String]("[(0,0),(1,2),(2,4),(3,6)]", non_string_string)

    let f_err = {()? =>
      let ring = Ring[MyNonStringable](4)
      for x in Range[U64](0,4) do
        ring.push(MyNonStringable(x, x*2))
      end
      ring.string()?
    }
    h.assert_error(f_err)

    // TODO: Once upstream ponyc is merged, replace this with h.assert_no_error
    let f_no_err = {(): String ? =>
      let ring = Ring[MyNonStringable](4)
      for x in Range[U64](0,4) do
        ring.push(MyNonStringable(x, x*2))
      end
      ring.string(where f = {(a: MyNonStringable): String
        =>
          "(".add(a.x.string()).add(",").add(a.y.string()).add(")")})?
    }
    h.assert_eq[String]("[(0,0),(1,2),(2,4),(3,6)]", f_no_err()?)

class val MyNonStringable
  let x: U64
  let y: U64

  new val create(x': U64, y': U64) =>
    x = x'
    y = y'

class iso _TestKeys is UnitTest
  fun name(): String => "ring/Keys"

  fun apply(h: TestHelper) =>
    let ring = Ring[U64].from_array(recover [2; 3; 4; 5] end, 4, 5)
    let keys: Array[USize] val = recover [0; 1; 2; 3] end
    let k_keys = keys.keys()
    let r_keys = ring.keys()
    for x in Range[USize](0,4) do
      h.assert_eq[USize](k_keys.next(), r_keys.next())
    end

class iso _TestValues is UnitTest
  fun name(): String => "ring/Values"

  fun apply(h: TestHelper) ? =>
    let ring = Ring[U64].from_array(recover [5; 2; 3; 4] end, 4, 5)
    let values: Array[U64] val = recover [5; 4; 3; 2] end
    let r_vals = ring.values()
    let v_vals = values.values()
    for x in Range[USize](0,4) do
      h.assert_eq[U64](v_vals.next()?, r_vals.next()?)
    end

class iso _TestPairs is UnitTest
  fun name(): String => "ring/Pairs"

  fun apply(h: TestHelper) ? =>
    let ring = Ring[U64].from_array(recover [5; 2; 3; 4] end, 4, 5)
    let values: Array[U64] val = recover [5; 4; 3; 2] end
    let r_pairs = ring.pairs()
    let v_pairs = values.pairs()
    for x in Range[USize](0,4) do
      (let ri, let rv) = r_pairs.next()?
      (let vi, let vv) = v_pairs.next()?
      h.assert_eq[USize](vi, ri)
      h.assert_eq[U64](vv, rv)
    end
