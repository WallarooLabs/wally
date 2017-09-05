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

actor TestMain is TestList
  new create(env: Env) => Connemara(env, this)

  new make() => None

  fun tag tests(test: Connemara) =>
    test(_TestSentLogEncoder)

class iso _TestSentLogEncoder is UnitTest
  """
  Verify that the giles sender log encoder is encoding individual lines as
  expected
  """
  fun name(): String => "giles/sender:SentLogEncoder"

  fun apply(h: TestHelper) =>
    let encoder = SentLogEncoder

    let hello_world = encoder(("Hello World", 95939399))
    h.assert_eq[String](hello_world,"95939399, Hello World")

    let hello_walken= encoder(("Hello, World: The Christopher Walken Story",
    23123213))
    h.assert_eq[String](hello_walken,
    "23123213, Hello, World: The Christopher Walken Story")

    let one = encoder(("1", 1))
    h.assert_eq[String](one, "1, 1")

    let ten = encoder(("10", 2))
    h.assert_eq[String](ten, "2, 10")

    let one_hundred = encoder(("100", 3))
    h.assert_eq[String](one_hundred, "3, 100")

    let one_thousand = encoder(("1000", 4))
    h.assert_eq[String](one_thousand, "4, 1000")
