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
    test(_TestWindow)
    test(_TestMessage)

class iso _TestWindow is UnitTest
  fun name(): String => "bulding_blocks/Window"

  fun apply(h: TestHelper) ? =>
    let w = Window(WindowSize())
    let last: Value = 10
    let diff: Value = (WindowSize() - 1).u64()
    for x in Range[Value](0, (last+1)) do
      w.push(x)
    end
    h.assert_eq[Value](last, w(0)?)
    h.assert_eq[Value]((last-diff), w(w.size()-1)?)


class iso _TestMessage is UnitTest
  fun name(): String => "building_blocks/Message"

  fun apply(h: TestHelper) =>
    let ceil: Value = (WindowSize() + 1).u64()
    let w: Window val = recover
      let w' = Window(WindowSize())
      for x in Range[Value](0, ceil) do
        w'.push(x)
      end
      consume w'
    end

    let key: Key = "key"
    let trace: String = "trace"
    // test Message with window
    let m1: Message = Message(key, trace, w)
    h.assert_eq[Key](key, m1.key())
    h.assert_eq[Value]((ceil-1), m1.value())
    h.assert_eq[String](trace, m1.trace())

    // test Message with Value
    let m2: Message = Message(key, trace, (ceil-1))
    h.assert_eq[Key](key, m2.key())
    h.assert_eq[Value]((ceil-1), m2.value())
    h.assert_eq[String](trace, m2.trace())
